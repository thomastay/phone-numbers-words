; A nim translation of https://norvig.com/java-lisp.html
; func isSingleDigit(s: string): bool = s.len == 1

; func onlyDigits(s: string): string =
;   result = newStringOfCap(s.len)
;   for c in s:
;     if c in '0'..'9':
;       result.add c

; proc printTranslation(num, digits: string, words: Table[string, seq[string]]) =
;   ## Prints the phone number, and the words that make it up
;   ## e.g. 0886/7/-59063/276-9458140: 0 Opium 9 Eid Wucht Mont 0
;   ## Runs recursively. see Norvig's post for a description.
;   var wordList = newSeqOfCap[string](digits.len)
;   proc helper(start: int) =
;     if start >= digits.len:
;       let joinedWords = wordList.join(" ")
;       echo &"{num}: {joinedWords}"
;       return
;     var 
;       foundWord = false
;       s = newStringOfCap(digits.len - start)
;     for i in start..<digits.len:
;       s.add digits[i]
;       if s in words:
;         foundWord = true
;         for word in words[s]:
;           wordList.add(word)
;           helper(i + 1)
;           discard wordList.pop()
;     if not foundWord and (wordList.len() == 0 or not wordList[^1].isSingleDigit()):
;       wordList.add($digits[start])
;       helper(start + 1)
;       discard wordList.pop()
;   helper(0)

; when isMainModule:
;   let dictionaryFilename = paramStr(1)
;   let phoneNumberFilename = paramStr(2)
;   let dict = open(dictionaryFilename)

;   var words: Table[string, seq[string]]
;   for word in dict.lines:
;     words.mgetOrPut(wordToString(word), @[]).add(word)
;   let nums = open(phoneNumberFilename)
;   for num in nums.lines:
;     printTranslation(num, num.onlyDigits(), words)
  
;   nums.close()
;   dict.close()
;   
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

(defn -main
  "hello, world!"
  [& _args]
  (let [dict (with-open
              [rdr (reader "resources/dictionary_small.txt")]
               (group-by word->str (line-seq rdr)))]
    (with-open
     [rdr (reader "resources/input_small.txt")]
      (mapv
       #(create-translations (only-digits %1) dict)
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
      (when r (conj r "mir")))))
