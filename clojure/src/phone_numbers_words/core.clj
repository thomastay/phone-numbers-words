; A clojure translation of https://norvig.com/java-lisp.html
(ns phone-numbers-words.core
  (:require [clojure.java.io :refer [reader]]
            [clojure.string :as str])
  (:gen-class))

(def char->digit
  {\e \0
   \j \1, \n \1, \q \1
   \r \2, \w \2, \x \2
   \d \3, \s \3, \y \3
   \f \4, \t \4
   \a \5, \m \5
   \c \6, \i \6, \v 6
   \b \7, \k \7, \u 7
   \l \8, \o \8, \p 8
   \g \9, \h \9, \z 9})

(defn word->str
  "Takes a word (a string), removes all non-letters, casts it to lowercase,
   then applies the char->digit map on it. Returns a string."
  [word]
  (apply str
         (map
          #(get char->digit (Character/toLowerCase %1))
          (filter #(Character/isLetter %1) word))))

(defn gen-substrings
  "Generates all substrings for a string s, starting at index i (0 indexed)
   and going all the way to the end."
  [s i]
  (map #(subs s i (inc %1))
       (range i (count s))))

(defn only-digits [s]
  (apply str (filter #(Character/isDigit %1) s)))

(defn conj-words-to-vecs
  "Adds each word in words to each vector in v
   @words is a vector; @v is a seq of vectors
   e.g. (conj-words-to-vecs [F G] 
                             [[H C] [H E]]) 
   -> 
    ([H C F] [H E F] [H C G] [H E F])
   if v is nil or empty, returns nil"
  [words v] (when (seq v)
              (mapcat (fn [w]
                        (map #(conj %1 w) v))
                      words)))

(defn keepcat
  "Returns a lazy sequence of concatenating the non-nil
   results of (f item). The parallel of mapcat."
  [f coll] (apply concat (keep f coll)))

(defn create-translations-impl
  "Private implementation of create-translations. See the docstring there.
   `i` is the starting index of the recursion
   `last-word-digit?` is a bool that describes whether the parent recursive call
   is called based on pushing a single digit. To quote Norvig:
   > The rules say that in addition to dictionary words, you can use a single 
     digit in the output, but not two digits in a row. Also (and this seems 
     silly) you can't have a digit in a place where any word could appear.
   To handle this, I make the parent caller pass down a bool called last-word-digit?

   ## Implementation:
   Unlike Norving's solution, this solution builds up the list of translations bottom-up
   That means, instead of building a words list down the call chain, printing at the end,
   we instead build a seq of vectors of words that `digits` translates into.
   Example:
   (def dict {12: a, 3: b, 1: c, 23: d})
   (create-translation 123 dict 0 false) -> ([b a] [d c])
   (create-translation 123 dict 1 false) -> ([d])
   (create-translation 123 dict 2 false) -> ([b])"
  [digits dict i last-word-digit?]
  (if (>= i (count digits))
    ; Reached the end.
    [[]]
    (let [all-subs (gen-substrings digits i)
          ; translations is a seq of [len, word] pairs
          ; of translated words that start at position i.
          ; If there are no translations, returns ().
          ;   e.g. Suppose digits = 56278, i = 0
          ;   and that 562 maps to [mir, Mix] in the dict,
          ;   and no other subsequence starting at pos 0 is in the dict,
          ;   then translations will be ([3 mir] [3 Mix]),
          ;   since 562 has length 3
          translations
          (keep
           (fn [s]
             (when-let [v (dict s)]
               [(count s) v]))
           all-subs)]
       ; If translations is non-nil, that means we found some words.
       ; Recursively call create-translations for all translations
       ; and apply conj-words-to-vecs on the seq. 
       ; We get a seq of seq of vecs, of which we want to keep the non-nil elts,
       ; and then cast it into a seq of vecs (by applying concat)
       ; We then apply seq to it again, to ensure that if keepcat returns (),
       ; we cast it to nil.
      (if (seq translations)
        (seq (keepcat (fn [[len words]]
                        (conj-words-to-vecs
                         words
                         (create-translations-impl digits dict (+ len i) false)))
                      translations))
         ; if we did not find any words, and last word was not a digit,
         ; try a recursive call that pushes a single digit.
        (when-not last-word-digit?
          (when-let [result (create-translations-impl digits dict (+ i 1) true)]
            (-> (get digits i)
                (str)
                (vector)
                (conj-words-to-vecs result))))))))

(defn create-translations
  "Returns a vector of vectors for translations of a given phone number.
   `digits` are the digits of the phone number.
   The input phone number must be only digits.
   `dict` is the dictionary of phone numbers -> words,
   generated from the dictionary file.
   The vectors returned are in reverse order.

   Example:
   (def dict {12: a, 3: b, 1: c, 23: d})
   (create-translation 123 dict) -> ([b a] [d c])"
  [digits dict]
  (create-translations-impl digits dict 0 false))

(defn -main
  "hello, world!"
  [& _args]
  (let [dict (with-open
              [rdr (reader "resources/dictionary_small.txt")]
               (group-by word->str (line-seq rdr)))]
    (with-open
     [rdr (reader "resources/input_small.txt")]
      (doseq [s (line-seq rdr)
              :let [translations
                    (-> s
                        (only-digits)
                        (create-translations dict))]]
        (run!
         #(println (str s ": " (str/join " " (reverse %1))))
         translations)))))

(comment
  (def dict (with-open
             [rdr (reader "resources/dictionary_small.txt")]
              (group-by word->str (line-seq rdr))))
  (def input (str/split-lines (slurp "resources/input_small.txt")))
  (def mock-result [["H" "C"] ["H" "D"] ["H" "E"]])
  (map #(conj %1 "Z") mock-result)
  (def test-word "107835")
  (create-translations test-word dict)
  (create-translations "07216084067" dict)
  (seq (keep identity '()))
  (str (get "1235" 3))
  (->> "123"
       (println "asd"))
  (create-translations "4824" dict)
  (-> \4
      (str)
      (vector)
      (conj-words-to-vecs [["a" "d"]]))
  (doseq [x (filter even? (range 10))]
    (println x))
  (def test-str '("123" "asd"))
  (println (str/join " " test-str))
  (-main))

  ;; First, we generate all substrings starting at i
  ;; Then, for each substring, I check if it is in *dict*
  ;; Then, for each sub in dict, I retrive the vector v of translations
  ;; For each translation, I call create-translations recursively, to get back
  ;; a vector of a vector, result-lists
  ;; for each vector in result-lists, conj my translation to it. 
  ;; e.g. if (create-translations) returns [[H C] [H D] [H E]], and my word is Z,
  ;; I want to obtain [[H C Z] [H D Z] [H E Z]]
  ;; e.g. if (create-translations) returns [[]]

