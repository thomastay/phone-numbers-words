#!/usr/bin/env python3
## A python translation of https://norvig.com/java-lisp.html

charToDigit = {
    "e": "0",
    "j": "1", "n": "1", "q": "1",
    "r": "2", "w": "2", "x": "2",
    "d": "3", "s": "3", "y": "3",
    "f": "4", "t": "4",
    "a": "5", "m": "5",
    "c": "6", "i": "6", "v": "6",
    "b": "7", "k": "7", "u": "7",
    "l": "8", "o": "8", "p": "8",
    "g": "9", "h": "9", "z": "9",
}


def wordToString(word):
    return "".join(charToDigit[c.lower()] for c in word if c.isalpha())


def onlyDigits(s):
    return "".join(c for c in s if c.isdigit())


def allSubsStartingAt(s, i):
    return (s[i:idx] for idx in range(i + 1, len(s) + 1))


def printTranslation(num, digits, words):
    ## Prints the phone number, and the words that make it up
    ## e.g. 0886/7/-59063/276-9458140: 0 Opium 9 Eid Wucht Mont 0
    ## Runs recursively. see Norvig's post for a description.
    wordList = []

    def helper(start):
        if start >= len(digits):
            joinedWords = " ".join(wordList)
            print(f"{num}: {joinedWords}")
            return
        foundWord = False
        for i, s in enumerate(allSubsStartingAt(digits, start)):
            if s in words:
                foundWord = True
                for word in words[s]:
                    wordList.append(word)
                    helper(i + start + 1)
                    wordList.pop()
        if not foundWord and (len(wordList) == 0 or not len(wordList[-1]) == 1):
            wordList.append(digits[start])
            helper(start + 1)
            wordList.pop()

    helper(0)


if __name__ == "__main__":
    import sys
    from collections import defaultdict

    dictionaryFilename = sys.argv[1]
    phoneNumberFilename = sys.argv[2]
    words = defaultdict(list)
    with open(dictionaryFilename) as myDict:
        for word in myDict:
            word = word.rstrip()
            words[wordToString(word)].append(word)
    with open(phoneNumberFilename) as nums:
        for num in nums:
            num = num.rstrip()
            printTranslation(num, onlyDigits(num), words)
