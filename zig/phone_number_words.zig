/// A Zig translation of https://norvig.com/java-lisp.html
// Qn: it is really easy to make a typo here! Why can't we just say import {mem, Allocator} from std?
const std = @import("std");
const expectEqualStrings = std.testing.expectEqualStrings;
const fs = std.fs;
const mem = std.mem;
const Dir = std.fs.Dir;
const Allocator = std.mem.Allocator;
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
fn wordToString(word: []const u8, output: []u8) []u8 {
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
    const result = try fs.File.Reader.readUntilDelimiterOrEofAlloc(self, allocator, '\r', MAX_DICT_WORD_SIZE);
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

fn readDictionary(ally: *Allocator, rdr: fs.File.Reader) !StringHashMap(ArrayList([]const u8)) {
    var words = StringHashMap(ArrayList([]const u8)).init(ally);
    var wordToStrBuf: [MAX_DICT_WORD_SIZE]u8 = undefined;
    while (try readUntilEolOrEofAlloc(rdr, ally)) |dictWord| {
        std.debug.print("{s}: {s}\n", .{ wordToString(dictWord, &wordToStrBuf), dictWord });
        const digits = wordToString(dictWord, &wordToStrBuf);
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

pub fn main() !void {
    // Allocator setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // why the {}?
    var gpaAlly = &gpa.allocator;
    defer std.debug.assert(!gpa.deinit()); // no leaks

    // To simplify things, we use an arena to allocate memory and free it in one go.
    var dictArena = std.heap.ArenaAllocator.init(gpaAlly);
    defer dictArena.deinit();
    const words = blk: {
        // read in the hash table from dictionary file
        // NOTE: this absolute path hackery is to get over relative paths on windows error
        // will change soon
        // NOTE: I gave up on the relative path bs, it just works by copying it in, lol.
        // var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        // const dictFilename = try Dir.realpath(fs.cwd(), "dictionary_small.txt", &buf);
        // std.debug.print("{s}", .{dictFilename});
        var dictFile = try Dir.openFile(fs.cwd(), "dictionary_small.txt", .{});
        defer dictFile.close();
        var dictReader = fs.File.reader(dictFile);
        break :blk readDictionary(&dictArena.allocator, dictReader);
    };
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
