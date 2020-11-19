## A nim translation of https://norvig.com/java-lisp.html

import tables, strformat, strutils, os
const charToDigit: Table[char, char] = {
  'e': '0',
  'j': '1', 'n': '1', 'q': '1',
  'r': '2', 'w': '2', 'x': '2',
  'd': '3', 's': '3', 'y': '3',
  'f': '4', 't': '4',
  'a': '5', 'm': '5',
  'c': '6', 'i': '6', 'v': '6',
  'b': '7', 'k': '7', 'u': '7',
  'l': '8', 'o': '8', 'p': '8',
  'g': '9', 'h': '9', 'z': '9',
}.toTable

func wordToString(word: string): string =
  result = newStringOfCap(word.len)
  for c in word:
    if c in {'a'..'z', 'A'..'Z'}:
      result.add charToDigit[c.toLowerAscii()]

func isSingleDigit(s: string): bool = s.len == 1

func onlyDigits(s: string): string =
  result = newStringOfCap(s.len)
  for c in s:
    if c in '0'..'9':
      result.add c


proc printTranslation(num, digits: string, words: Table[string, seq[string]]) =
  ## Prints the phone number, and the words that make it up
  ## e.g. 0886/7/-59063/276-9458140: 0 Opium 9 Eid Wucht Mont 0
  ## Runs recursively. see Norvig's post for a description.
  var wordList = newSeqOfCap[string](digits.len)
  proc helper(start: int) =
    if start >= digits.len:
      let joinedWords = wordList.join(" ")
      echo &"{num}: {joinedWords}"
      return
    var 
      foundWord = false
      s = newStringOfCap(digits.len - start)
    for i in start..<digits.len:
      s.add digits[i]
      if s in words:
        foundWord = true
        for word in words[s]:
          wordList.add(word)
          helper(i + 1)
          discard wordList.pop()
    if not foundWord and (wordList.len() == 0 or not wordList[^1].isSingleDigit()):
      wordList.add($digits[start])
      helper(start + 1)
      discard wordList.pop()
  helper(0)

when isMainModule:
  let dictionaryFilename = paramStr(1)
  let phoneNumberFilename = paramStr(2)
  let dict = open(dictionaryFilename)

  var words: Table[string, seq[string]]
  for word in dict.lines:
    words.mgetOrPut(wordToString(word), @[]).add(word)
  let nums = open(phoneNumberFilename)
  for num in nums.lines:
    printTranslation(num, num.onlyDigits(), words)
  
  nums.close()
  dict.close()
  




