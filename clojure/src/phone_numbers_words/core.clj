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

(defn- gen-substrings
  "Generates all substrings for a string s, starting at index i (0 indexed)
   and going all the way to the end."
  [s i]
  (map #(subs s i (inc %1))
       (range i (count s))))

(defn- only-digits [s]
  (apply str (filter #(Character/isDigit %1) s)))

(defn create-translations
  "Returns a seq of vectors for translations of a given phone number.
   @param digits are the digits of the phone number
   The input phone number must be only digits (i.e. filtering must be done outside
   this function)
   @param dict is the dictionary of phone numbers -> words,
   generated from the dictionary file"
  ([digits dict]
   (create-translations digits dict 0 []))
  ([digits dict start-idx result]
   (if (>= start-idx (count digits))
     result
     ; else:
     ; creates substrings of s[start], s[start..1], s[start..2], etc
     ; For each substring, call Map.get, and keep it if it is non-nil
     ; Then, foreach item in the returned vector, recursively call create-translations
     (let [all-subs (gen-substrings digits start-idx)]
       (keep
        (fn [s]
          (let [new-idx (+ start-idx (count s))]
            (when (contains? dict s)
              (map
               #(create-translations digits dict new-idx (conj result %1))
               (get dict s)))))
        all-subs)))))

(defn conj-words-to-vecs
  "Adds each word in words to each vector in v
   @words is a vector; @v is a vector of vectors
   e.g. (conj-words-to-vecs [F G] 
                             [[H C] [H E]]) 
   -> 
    [[H C F] [H E F] [H C G] [H E F]]
   if v is nil, returns nil"
  [words v] (when v
              (mapcat (fn [w]
                        (map #(conj %1 w) v))
                      words)))

(defn create-translations-v2
  "Returns a vector of vectors for translations of a given phone number.
   @digits are the digits of the phone number.
   The input phone number must be only digits.
   @dict is the dictionary of phone numbers -> words,
   generated from the dictionary file."
  ([digits dict]
   (create-translations-v2 digits dict 0))
  ([digits dict i]
   (if (>= i (count digits))
     ; Reached the end, return an empty vec of vecs
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
           (keep (fn [s]
                   (when-let [v (get dict s)]
                     [(count s) v]))
                 all-subs)]
       ; if translations is empty, return nil
       (when (seq translations)
         (apply vec
                (keep (fn [[len words]]
                        (conj-words-to-vecs
                         words
                         (create-translations-v2 digits dict (+ len i))))
                      translations)))))))

(defn -main
  "hello, world!"
  [& _args]
  (let [dict (with-open
              [rdr (reader "resources/dictionary_small.txt")]
               (group-by word->str (line-seq rdr)))]
    (with-open
     [rdr (reader "resources/input_small.txt")]
      (mapv
       (fn [s]
         (-> s
             (only-digits)
             (create-translations-v2 dict)))
       (line-seq rdr)))))

(comment
  (def dict (with-open
             [rdr (reader "resources/dictionary_small.txt")]
              (group-by word->str (line-seq rdr))))
  (def input (str/split-lines (slurp "resources/input_small.txt")))
  (create-translations "5627857" dict 0 [])
  (defn create' [i]
    (let [all-subs (gen-substrings "5627857" i)
          r (create' 3)]
      (when r (conj r "mir"))))
  (def mock-result [["H" "C"] ["H" "D"] ["H" "E"]])
  (map #(conj %1 "Z") mock-result)
  (defn add-words-to-result
    "Words must be a vector of strings
     (add-words-to-result [F G] mock-result) -> 
     [[H C F] [H D F] [H E F] [H C G] ... ]"
    [words v] (when v
                (mapcat (fn [w]
                          (map #(conj %1 w) v))
                        words)))
  (add-words-to-result ["F" "G"] mock-result)
  (mapcat #(add-words-to-result %1 mock-result) '(["F" "G"] ["H"]))
  (def test-word "5627857")
  (defn first-translations
    "Returns a seq of [len, word] pairs, of words that start at position i.
     e.g. (first-translations 5627857 0) -> [3, [mir, Mix]],
     supposing that 562 maps to [mir, Mix] in the dictionary,
     and no other subsequence starting at 0 is in the dictionary."
    [i] (keep (fn [s]
                (when-let [v (get dict s)]
                  [(count s) v]))
              (gen-substrings test-word i)))
  (defn create-v2
    [i]
    (if (>= i (count test-word))
      ; Reached the end, return an empty vec of vecs
      [[]]
      (let [translations (first-translations i)]
        ; if translations is empty, return nil
        (when (seq translations)
          (apply vec
                 (keep (fn [[len words-vec]]
                         (add-words-to-result words-vec
                                              (create-v2 (+ len i))))
                       translations))))))
  (create-v2 0)
  (seq? (create-v2 5))
  (add-words-to-result ["asd"] nil)
  (mapv
   (fn [s]
     (-> s
         (only-digits)
         #(create-translations-v2 %1 dict)))
   input)
  (macroexpand
   '(-> s
        (only-digits)
        (create-translations-v2 dict))))

  ;; First, we generate all substrings starting at i
  ;; Then, for each substring, I check if it is in *dict*
  ;; Then, for each sub in dict, I retrive the vector v of translations
  ;; For each translation, I call create-translations recursively, to get back
  ;; a vector of a vector, result-lists
  ;; for each vector in result-lists, conj my translation to it. 
  ;; e.g. if (create-translations) returns [[H C] [H D] [H E]], and my word is Z,
  ;; I want to obtain [[H C Z] [H D Z] [H E Z]]
  ;; e.g. if (create-translations) returns [[]]

