/// A Zig translation of https://norvig.com/java-lisp.html
/// This is a fun little exercise that I use when learning a new language.
/// I've done this previous excursion in Nim and Clojure and Python (https://github.com/thomastay/phone-numbers-words)
/// The gist of this problem is as such: Given some mapping of letters to digits,
/// we want to "translate" a phone number into a series of words that encode the phone number
/// The words will be given to us via some dictionary.
/// The full instructions are here: https://github.com/thomastay/phone-numbers-words/blob/master/resources/test_instructions.txt
///
/// For instance, given the mapping below, and a dictionary of words:
/// MAPPING:
///       E | J N Q | R W X | D S Y | F T | A M | C I V | B K U | L O P | G H Z
///       e | j n q | r w x | d s y | f t | a m | c i v | b k u | l o p | g h z
///       0 |   1   |   2   |   3   |  4  |  5  |   6   |   7   |   8   |   9
/// DICT: {hell, hello, o, world, row, oy}
/// we might encode the number 908-882-8283 in 4 different ways:
///    1. hello world
///    2. hell o world
///    3. hello row oy
///    4. hell o row oy
///
// Note: it is really easy to make a typo here! Why can't we just say import {mem, Allocator} from std?
// Note: Right now, the perf bottleneck on linux appears to be the reading of the input dictionary...
// Note: does Zig have bigints? That might speed it up.
const std = @import("std");
const builtin = @import("builtin");
const expectEqualStrings = std.testing.expectEqualStrings;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;

// constants specified in test-instructions.txt
const MAX_DICT_WORD_SIZE = 50;
const MAX_PHONE_NUMBER_SIZE = 50;

/// Constants and User defined types.
/// charToDigit is the mapping specified in test-instructions.txt
/// it maps a lowercase a-z character to a digit in 0-9.
const charToDigit: [26]u8 = createDigitMap();
const WordsDictionary = StringHashMap(ArrayList([]const u8));
// Note: can I merge error unions? Would like to write this inline in the function... (answer: yes!)

pub fn main() !void {
    // Allocator setup
    // Note: GPA is great for debugging, works like it says on the tin and catches all leaks.
    // but how do I swap it out at build time, based on the build config?
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // Note: why the {}? I learnt this through copy-paste
    var gpaAlly = gpa.allocator();
    defer std.debug.assert(!gpa.deinit()); // no leaks

    const argv = try std.process.argsAlloc(gpaAlly);
    defer std.process.argsFree(gpaAlly, argv);
    if (argv.len != 3) {
        try std.io.getStdOut().writer().print("Usage: ./phone_number_words <dict filename> <input filename>", .{});
        return;
    }
    const dictFilename = argv[1];
    const inputFilename = argv[2];

    // Read the dictionary from a file.
    var dictArena = std.heap.ArenaAllocator.init(gpaAlly);
    defer dictArena.deinit();
    const words: WordsDictionary = blk: {
        var dictFile = try fs.Dir.openFile(fs.cwd(), dictFilename, .{});
        defer dictFile.close();
        var dictReader = std.io.bufferedReader(fs.File.reader(dictFile)).reader();
        break :blk try readDictionary(dictArena.allocator(), &dictReader);
    };

    // Read the phone numbers from a file, and print the translations.
    var inputFile = try fs.Dir.openFile(fs.cwd(), inputFilename, .{});
    defer inputFile.close();
    var inputReader = std.io.bufferedReader(fs.File.reader(inputFile)).reader();
    var phoneNumberBuf: [MAX_PHONE_NUMBER_SIZE]u8 = undefined;
    var phoneNumberDigitsBuf: [MAX_PHONE_NUMBER_SIZE]u8 = undefined;
    while (try readUntilEolOrEof(&inputReader, &phoneNumberBuf)) |num| {
        try printTranslation(gpaAlly, num, onlyDigits(num, &phoneNumberDigitsBuf), words);
    }
}

/// Reads a dictionary from the given Reader (declared anytype to be generic)
/// Returns a hashmap from str -> ArrayList
fn readDictionary(ally: Allocator, rdr: anytype) !WordsDictionary {
    var words = WordsDictionary.init(ally);
    var wordToStrBuf: [MAX_DICT_WORD_SIZE]u8 = undefined;
    while (try readUntilEolOrEofAlloc(rdr, ally, MAX_DICT_WORD_SIZE)) |dictWord| {
        const digits = wordToNumber(dictWord, &wordToStrBuf);

        const ret = try words.getOrPut(digits);
        if (ret.found_existing) {
            try ret.value_ptr.append(dictWord);
        } else {
            var vec = try ArrayList([]const u8).initCapacity(ally, 1);
            try vec.append(dictWord); // Note: can I declare this inline with the previous line?
            ret.key_ptr.* = try ally.dupe(u8, digits);
            ret.value_ptr.* = vec;
        }
    }
    return words;
}

/// For a given phone number and a the digits of the phone number
/// prints the phone number and all combinations of words that might encode the phone number
/// It sets up some allocators and variables, then calls printTranslationImpl, which is a recursive function.
fn printTranslation(ally: Allocator, number: []const u8, digits: []const u8, words: WordsDictionary) !void {
    var arena = ArenaAllocator.init(ally);
    var allocator = arena.allocator();
    defer arena.deinit();
    var wordList = try ArrayList([]const u8).initCapacity(allocator, digits.len);
    var bufWriter = std.io.bufferedWriter(std.io.getStdOut().writer());
    try printTranslationImpl(&wordList, 0, &bufWriter.writer(), allocator, number, digits, words);
    try bufWriter.flush(); // Note: why is this needed? Should I flush later? When do I flush?
    // also, is it possible to flush on defer? Currently, I cannot do it, since it contains a try.
}

// Note: why must out be a ptr to a BufWriter? If not, it says that it violates const correctness. (ANS: because parameters are const)
// Note: is there no good way to abstract over writers? (Ans: anytype, generics, etc)
/// This function prints the encodings of the phone numbers recursively
/// Here is an example input
/// ```zig
///   number:   908-882-8283
///   digits:   9088828283
///   start: 4      ^
/// //      start points here!
///   wordList: ["hell"]     // <-- 9088 maps to 'hell'
/// ```
/// To recursively generate the rest of the numbers, we perform a DFS, slicing from the start index
/// onwards. Once we reach the end of the word, we print out the wordlist.
/// After the function returns, we pop the wordList to restore the stack back to its original position.
/// Unfortunately, we have an edge case specified in the test instructions, whereby if no word matches at a given
/// position, we are allowed to use a single digit (and no more!) in its place.
/// The if-branch after the while statement handles this edge case.
fn printTranslationImpl(
    wordList: *ArrayList([]const u8),
    start: usize,
    out: anytype,
    ally: Allocator,
    number: []const u8,
    digits: []const u8,
    words: WordsDictionary, // must have trailing slash so zigfmt doesn't try to put the parameters on one line
) (std.os.WriteError || error{OutOfMemory})!void {
    if (start >= digits.len) {
        // Base case, print everything inside of wordList and end recursion
        try out.print("{s}: ", .{number});
        for (wordList.items) |word| {
            try out.print("{s} ", .{word});
        }
        try out.print("\n", .{});
    } else {
        var foundWord = false;
        var keyBuf: [MAX_PHONE_NUMBER_SIZE]u8 = undefined;
        var i: usize = 0;
        while (i < digits.len - start) : (i += 1) {
            const startIdxDigits = i + start;
            keyBuf[i] = digits[startIdxDigits];
            const key = keyBuf[0 .. i + 1];
            if (words.get(key)) |wordsMappedToDigit| {
                foundWord = true;
                for (wordsMappedToDigit.items) |word| {
                    try wordList.append(word);
                    try printTranslationImpl(wordList, startIdxDigits + 1, out, ally, number, digits, words);
                    _ = wordList.pop();
                }
            }
        }
        if (!foundWord and (wordList.items.len == 0 or wordList.items[wordList.items.len - 1].len != 1)) {
            var singleDigit = try ally.create([1]u8);
            singleDigit[0] = digits[start]; // note: can I declare this inline?
            try wordList.append(singleDigit);
            try printTranslationImpl(wordList, start + 1, out, ally, number, digits, words);
            _ = wordList.pop();
        }
    }
}

// Note: I started by creating a heap allocated hash map, before realizing
// all I really needed was a fixed size hash map.
/// Creates the digit map specified in the instructions
/// takes as input a buffer of 26 ints
fn createDigitMap() [26]u8 {
    var result: [26]u8 = undefined;
    result['e' - 'a'] = '0';
    result['j' - 'a'] = '1';
    result['n' - 'a'] = '1';
    result['q' - 'a'] = '1';
    result['r' - 'a'] = '2';
    result['w' - 'a'] = '2';
    result['x' - 'a'] = '2';
    result['d' - 'a'] = '3';
    result['s' - 'a'] = '3';
    result['y' - 'a'] = '3';
    result['f' - 'a'] = '4';
    result['t' - 'a'] = '4';
    result['a' - 'a'] = '5';
    result['m' - 'a'] = '5';
    result['c' - 'a'] = '6';
    result['i' - 'a'] = '6';
    result['v' - 'a'] = '6';
    result['b' - 'a'] = '7';
    result['k' - 'a'] = '7';
    result['u' - 'a'] = '7';
    result['l' - 'a'] = '8';
    result['o' - 'a'] = '8';
    result['p' - 'a'] = '8';
    result['g' - 'a'] = '9';
    result['h' - 'a'] = '9';
    result['z' - 'a'] = '9';
    return result;
}

// Note: from the error messages alone, it was hard to figure out what `word` should be
// Note: is it a good idea to modify the input slice?
/// Takes as input a word that contains digits and non digits, and an output buffer
/// Returns a slice of output buffer containing the mapped digits
/// according to the test instructions.
fn wordToNumber(word: []const u8, output: []u8) []u8 {
    std.debug.assert(word.len <= output.len); // output must have enough space

    // i points to word, j points to output
    var j: usize = 0;
    for (word) |c| {
        if (std.ascii.isAlpha(c)) {
            output[j] = charToDigit[std.ascii.toLower(c) - 'a'];
            j += 1;
        }
    }
    return output[0..j];
}

/// Takes as input a word that contains digits and non digits, and an output buffer
/// Returns a slice of output buffer containing only digits 0-9.
fn onlyDigits(word: []const u8, output: []u8) []u8 {
    std.debug.assert(word.len <= output.len); // output must have enough space

    // i points to word, j points to output
    var j: usize = 0;
    for (word) |c| {
        if (std.ascii.isDigit(c)) {
            output[j] = c;
            j += 1;
        }
    }
    return output[0..j];
}
// --------------------------------------------------------------------------------------
// ------------------------------- HELPER FUNCTIONS -------------------------------------
// --------------------------------------------------------------------------------------

// These functions are to handle the inability of the stdlib to handle CRLF line endings
fn readUntilEolOrEofAlloc(self: anytype, allocator: Allocator, max_size: usize) !?[]u8 {
    if (builtin.os.tag == .windows) {
        return readUntilCRLFOrEofAlloc(self, allocator, max_size);
    } else {
        return self.readUntilDelimiterOrEofAlloc(allocator, '\n', max_size);
    }
}

fn readUntilCRLFOrEofAlloc(self: anytype, allocator: Allocator, max_size: usize) !?[]u8 {
    const result_ = try self.readUntilDelimiterOrEofAlloc(allocator, '\r', max_size);
    if (result_) |result| {
        errdefer allocator.free(result);
        // Note: The above took me a while of code review to realize was necessary, since any errors
        // never occured in testing.

        // discard the \n if it exists
        const lf = self.readByte() catch |err| {
            switch (err) {
                error.EndOfStream => return result, // could theoretically happen, but practically never happens.
                else => return err,
            }
        };
        if (lf != '\n') {
            std.debug.panic("{} should have been \n", .{lf});
        }
        return result;
    } else {
        // end of stream
        return null;
    }
}

// These functions are to handle the inability of the stdlib to handle CRLF line endings
fn readUntilEolOrEof(self: anytype, buf: []u8) !?[]u8 {
    if (builtin.os.tag == .windows) {
        return readUntilCRLFOrEof(self, buf);
    } else {
        return self.readUntilDelimiterOrEof(buf, '\n');
    }
}

fn readUntilCRLFOrEof(self: anytype, buf: []u8) !?[]u8 {
    const result = try self.readUntilDelimiterOrEof(buf, '\r');
    if (result == null) return null;
    // discard the \n if it exists
    const lf = self.readByte() catch |err| {
        switch (err) {
            error.EndOfStream => return result,
            else => return err,
        }
    };
    if (lf != '\n') {
        std.debug.panic("{} should have been \n", .{lf});
    }
    return result;
}

// -----------------------------------------------------------------------------
// -------------------------------  TESTS  -------------------------------------
// -----------------------------------------------------------------------------

test "only Digits tests" {
    // Note: it was hard for me to find what to use! first i tried std.mem.eql, but that had issues
    // Then I had issues with expectEqualSlices
    // Then I finally got it working with expectEqualStrings, but i had to take the pointer of the array
    {
        var arrWithDigits = "h13e";
        var result: [arrWithDigits.len]u8 = undefined;
        expectEqualStrings(onlyDigits(arrWithDigits, &result), "13");
    }

    {
        var arrWithDigitsAtEnd = "h13e0";
        var result: [arrWithDigitsAtEnd.len]u8 = undefined;
        expectEqualStrings(onlyDigits(arrWithDigitsAtEnd, &result), "130");
    }

    {
        var arrWithDigitsAtStart = "4h13e0";
        var result: [arrWithDigitsAtStart.len]u8 = undefined;
        expectEqualStrings(onlyDigits(arrWithDigitsAtStart, &result), "4130");
    }

    {
        var emptyArr = "";
        var result: [emptyArr.len]u8 = undefined;
        expectEqualStrings(onlyDigits(emptyArr, &result), "");
    }

    {
        var onlyDigitArr = "3";
        var result: [onlyDigitArr.len]u8 = undefined;
        expectEqualStrings(onlyDigits(onlyDigitArr, &result), "3");
    }

    {
        var onlyCharArr = "x";
        var result: [onlyCharArr.len]u8 = undefined;
        expectEqualStrings(onlyDigits(onlyCharArr, &result), "");
    }
}
