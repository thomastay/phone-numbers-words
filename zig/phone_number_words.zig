/// A Zig translation of https://norvig.com/java-lisp.html
// Qn: it is really easy to make a typo here! Why can't we just say import {mem, Allocator} from std?
const std = @import("std");
const expectEqualStrings = std.testing.expectEqualStrings;
const fs = std.fs;
const mem = std.mem;
const Dir = std.fs.Dir;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const ascii = std.ascii;
const ArrayList = std.ArrayList;

const MAX_DICT_WORD_SIZE = 50;
// const MAX_WORDS_IN_DICT = 75000; // not important
const MAX_PHONE_NUMBER_SIZE = 50;

fn createDigitMap(allocator: *Allocator) !AutoHashMap(u8, u8) {
    var map = AutoHashMap(u8, u8).init(allocator);
    // !: Is there an easy way to initialize it at once?
    try map.put('e', '0');
    try map.put('j', '1');
    try map.put('n', '1');
    try map.put('q', '1');
    try map.put('r', '2');
    try map.put('w', '2');
    try map.put('x', '2');
    try map.put('d', '3');
    try map.put('s', '3');
    try map.put('y', '3');
    try map.put('f', '4');
    try map.put('t', '4');
    try map.put('a', '5');
    try map.put('m', '5');
    try map.put('c', '6');
    try map.put('i', '6');
    try map.put('v', '6');
    try map.put('b', '7');
    try map.put('k', '7');
    try map.put('u', '7');
    try map.put('l', '8');
    try map.put('o', '8');
    try map.put('p', '8');
    try map.put('g', '9');
    try map.put('h', '9');
    try map.put('z', '9');
    return map;
}

/// returns an array list with the mapped words.
/// callee must free the memory
/// !: It was super hard to figure out what the type of word should be! not obvious at all
fn wordToString(allocator: *Allocator, word: []const u8) !ArrayList(u8) {
    var s = try ArrayList(u8).initCapacity(allocator, word.len);
    for (word) |c| {
        if (ascii.isAlpha(c)) {
            const mappedChar = charToDigit.get(ascii.toLower(c)).?;
            try s.append(mappedChar);
        }
    }
    return s;
}

// modifies word such that it only contains digits
// the new word is returned.
// Note: if the entire string is non-digits,
fn onlyDigits(word: []u8) []u8 {
    // classic std::remove function
    // invariant: i <= j, j points to the first non-space char >= i
    var j: u32 = 0;
    var i: u32 = 0;
    while (j < word.len) : (j += 1) {
        if (ascii.isDigit(word[j])) {
            word[i] = word[j];
            i += 1;
        }
    }
    return word[0..i];
}

fn readUntilEolOrEof(self: fs.File.Reader, buf: []u8) !?[]u8 {
    const result = fs.File.Reader.readUntilDelimiterOrEof(self, buf, '\r');
    _ = try self.readByte(); // discard the \n
    return result;
}

pub fn main() !void {
    // Allocator setup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // why the {}?
    var allocator = &gpa.allocator;
    defer std.debug.assert(!gpa.deinit()); // no leaks

    // char->digit table setup
    var charToDigit = try createDigitMap(allocator);
    defer charToDigit.deinit();

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

    var dictWordBuf: [MAX_DICT_WORD_SIZE]u8 = undefined;
    const dictWord = try readUntilEolOrEof(dictReader, &dictWordBuf);
    std.debug.print("{s}", .{dictWord});
    const dictWord2 = try readUntilEolOrEof(dictReader, &dictWordBuf);
    std.debug.print("{s}", .{dictWord2});
}

test "only Digits tests" {
    // Note: it was hard for me to find what to use! first i tried std.mem.eql, but that had issues
    // Then I had issues with expectEqualSlices
    // Then I finally got it working with expectEqualStrings, but i had to take the pointer of the array
    var arrWithDigits = [_]u8{ 'h', '1', '3', 'e' };
    expectEqualStrings(onlyDigits(&arrWithDigits), &[_]u8{ '1', '3' });

    var arrWithDigitsAtEnd = [_]u8{ 'h', '1', '3', 'e', '0' };
    expectEqualStrings(onlyDigits(&arrWithDigitsAtEnd), &[_]u8{ '1', '3', '0' });

    var arrWithDigitsAtStart = [_]u8{ '4', 'h', '1', '3', 'e', '0' };
    expectEqualStrings(onlyDigits(&arrWithDigitsAtStart), &[_]u8{ '4', '1', '3', '0' });

    var emptyArr = [0]u8{};
    expectEqualStrings(onlyDigits(&emptyArr), &emptyArr);

    var onlyDigitArr = [_]u8{'3'};
    expectEqualStrings(onlyDigits(&onlyDigitArr), &onlyDigitArr);

    var onlyCharArr = [_]u8{'x'};
    expectEqualStrings(onlyDigits(&onlyCharArr), &emptyArr);
}
