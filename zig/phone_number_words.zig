/// A Zig translation of https://norvig.com/java-lisp.html
// Qn: it is really easy to make a typo here! Why can't we just say import {mem, Allocator} from std?
const std = @import("std");
const builtin = @import("builtin");
const expectEqualStrings = std.testing.expectEqualStrings;
const fs = std.fs;
const mem = std.mem;
const Dir = std.fs.Dir;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const StringHashMap = std.StringHashMap;
const ascii = std.ascii;
const ArrayList = std.ArrayList;

const MAX_DICT_WORD_SIZE = 50;
// const MAX_WORDS_IN_DICT = 75000; // not important
const MAX_PHONE_NUMBER_SIZE = 50;

const charToDigit = createDigitMap(); // force comptime evaluation

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

/// Takes as input a word that contains digits and non digits, and an output buffer
/// Returns a slice of output buffer.
/// Does not modify the original word
// Note: from the error messages alone, it was hard to figure out what `word` should be
fn wordToNumber(word: []const u8, output: []u8) []u8 {
    std.debug.assert(word.len <= output.len); // output must have enough space

    // i points to word, j points to output
    var j: usize = 0;
    for (word) |c, i| {
        if (ascii.isAlpha(c)) {
            output[j] = charToDigit[ascii.toLower(c) - 'a'];
            j += 1;
        }
    }
    return output[0..j];
}

/// Takes as input a word that contains digits and non digits, and an output buffer
/// Returns a slice of output buffer.
/// Does not modify the original word
fn onlyDigits(word: []const u8, output: []u8) []u8 {
    std.debug.assert(word.len <= output.len); // output must have enough space

    // i points to word, j points to output
    var j: usize = 0;
    for (word) |c, i| {
        if (ascii.isDigit(c)) {
            output[j] = c;
            j += 1;
        }
    }
    return output[0..j];
}

fn readUntilEolOrEofAlloc(self: fs.File.Reader, allocator: *Allocator) !?[]u8 {
    if (builtin.os.tag == builtin.Os.Tag.windows) {
        return readUntilCRLFOrEofAlloc(self, allocator);
    } else {
        return self.readUntilDelimiterOrEofAlloc(allocator, '\n', MAX_DICT_WORD_SIZE);
    }
}

fn readUntilCRLFOrEofAlloc(self: fs.File.Reader, allocator: *Allocator) !?[]u8 {
    const result = try self.readUntilDelimiterOrEofAlloc(allocator, '\r', MAX_DICT_WORD_SIZE);
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

fn readUntilEolOrEof(self: fs.File.Reader, buf: []u8) !?[]u8 {
    if (builtin.os.tag == builtin.Os.Tag.windows) {
        return readUntilCRLFOrEof(self, buf);
    } else {
        return self.readUntilDelimiterOrEof(buf, '\n');
    }
}

fn readUntilCRLFOrEof(self: fs.File.Reader, buf: []u8) !?[]u8 {
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

const WordsDictionary = StringHashMap(ArrayList([]const u8));

/// Reads a dictionary from the given Reader
/// Returns a hashmap from str -> ArrayList
fn readDictionary(ally: *Allocator, rdr: fs.File.Reader) !WordsDictionary {
    var words = WordsDictionary.init(ally);
    var wordToStrBuf: [MAX_DICT_WORD_SIZE]u8 = undefined;
    while (try readUntilEolOrEofAlloc(rdr, ally)) |dictWord| {
        const digits = wordToNumber(dictWord, &wordToStrBuf);
        // std.debug.print("{s}: {s}\n", .{ digits, dictWord });

        const ret = try words.getOrPut(digits);
        if (ret.found_existing) {
            try ret.entry.value.append(dictWord);
        } else {
            var vec = try ArrayList([]const u8).initCapacity(ally, 1);
            try vec.append(dictWord);
            ret.entry.key = try ally.dupe(u8, digits);
            ret.entry.value = vec;
        }
    }
    return words;
}
// Can I not hardcode this number? Should this number be exported by std.io?
const BufWriter = std.io.BufferedWriter(4096, fs.File.Writer);

// Note: can I merge error unions?
const PrintTranslationError = error{ DiskQuota, FileTooBig, InputOutput, NoSpaceLeft, AccessDenied, BrokenPipe, SystemResources, OperationAborted, NotOpenForWriting, WouldBlock, Unexpected, OutOfMemory };

// Note: why must out be a ptr to a BufWriter? If not, it says that it violates const correctness.
// Note: is there no good way to abstract over writers?
fn printTranslationImpl(wordList: *ArrayList([]const u8), start: usize, out: *BufWriter, ally: *Allocator, number: []const u8, digits: []const u8, words: WordsDictionary) PrintTranslationError!void {
    if (start >= digits.len) {
        // Base case, print everything inside of wordList and end recursion
        try out.writer().print("{s}: ", .{number});
        for (wordList.items) |word| {
            try out.writer().print("{s} ", .{word});
        }
        try out.writer().print("\n", .{});
    } else {
        var foundWord = false;
        var keyBuf: [MAX_PHONE_NUMBER_SIZE]u8 = undefined;
        var i: usize = 0;
        while (i < digits.len - start) : (i += 1) {
            const startIdxDigits = i + start;
            keyBuf[i] = digits[startIdxDigits];
            const key = keyBuf[0 .. i + 1];
            const v = words.get(key);
            if (v) |wordsMappedToDigit| {
                foundWord = true;
                for (wordsMappedToDigit.items) |word| {
                    try wordList.append(word);
                    try printTranslationImpl(wordList, startIdxDigits + 1, out, ally, number, digits, words);
                    _ = wordList.pop();
                }
            }
        }
        if (!foundWord and (wordList.items.len == 0 or wordList.items[wordList.items.len - 1].len != 1)) {
            // handle the edge case
            var singleDigit = try ally.create([1]u8);
            singleDigit[0] = digits[start];
            try wordList.append(singleDigit);
            try printTranslationImpl(wordList, start + 1, out, ally, number, digits, words);
            _ = wordList.pop();
        }
    }
}

fn printTranslation(ally: *Allocator, number: []const u8, digits: []const u8, words: WordsDictionary) !void {
    var arena = ArenaAllocator.init(ally);
    defer arena.deinit();
    var wordList = try ArrayList([]const u8).initCapacity(&arena.allocator, digits.len);
    var out = std.io.bufferedWriter(std.io.getStdOut().writer());
    try printTranslationImpl(&wordList, 0, &out, &arena.allocator, number, digits, words);
    try out.flush();
}

pub fn main() !void {
    // Allocator setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // why the {}?
    var gpaAlly = &gpa.allocator;
    defer std.debug.assert(!gpa.deinit()); // no leaks

    // Read the input filename and dictionary filename
    const argv = try std.process.argsAlloc(gpaAlly);
    defer std.process.argsFree(gpaAlly, argv);
    if (argv.len != 3) {
        try std.io.getStdOut().writer().print("Usage: ./phone_number_words <dict filename> <input filename>", .{});
        return;
    }
    const dictFilename = argv[1];
    const inputFilename = argv[2];
    // std.debug.print("dict filename: {s}, input filename: {s}", .{ argv[1], argv[2] });

    // To simplify things, we use an arena to allocate memory and free it in one go.
    var dictArena = std.heap.ArenaAllocator.init(gpaAlly);
    defer dictArena.deinit();
    const words: WordsDictionary = blk: {
        // read in the hash table from dictionary file
        // NOTE: this absolute path hackery is to get over relative paths on windows error
        // will change soon
        // NOTE: I gave up on the relative path bs, it just works by copying it in, lol.
        // var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        // const dictFilename = try Dir.realpath(fs.cwd(), "dictionary_small.txt", &buf);
        // std.debug.print("{s}", .{dictFilename});
        var dictFile = try Dir.openFile(fs.cwd(), dictFilename, .{});
        defer dictFile.close();
        var dictReader = fs.File.reader(dictFile);
        break :blk try readDictionary(&dictArena.allocator, dictReader);
    };
    // Handle the Input file
    var inputFile = try Dir.openFile(fs.cwd(), inputFilename, .{});
    defer inputFile.close();
    var inputReader = fs.File.reader(inputFile);
    var phoneNumberBuf: [MAX_PHONE_NUMBER_SIZE]u8 = undefined;
    var phoneNumberDigitsBuf: [MAX_PHONE_NUMBER_SIZE]u8 = undefined;
    while (try readUntilEolOrEof(inputReader, &phoneNumberBuf)) |num| {
        try printTranslation(gpaAlly, num, onlyDigits(num, &phoneNumberDigitsBuf), words);
    }
}

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
