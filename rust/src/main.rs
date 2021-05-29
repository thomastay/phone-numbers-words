#![allow(missing_docs)] // don't publish a crate with this!
#![allow(dead_code)] // don't publish a crate with this!
#![deny(rust_2018_idioms)]
#![deny(clippy::too_many_arguments)]
#![deny(clippy::complexity)]
#![deny(clippy::perf)]
#![forbid(unsafe_code)]
#![warn(clippy::style)]
#![warn(clippy::pedantic)]

use std::{
    collections::HashMap,
    error::Error,
    fs::File,
    io::{BufRead, BufReader},
    path::Path,
};

const DIGIT_MAP: [u8; 26] = [
    53, 55, 54, 51, 48, 52, 57, 57, 54, 49, 55, 56, 53, 49, 56, 56, 49, 50, 51, 52, 55, 54, 50, 50,
    51, 57,
]; // auto gen-ed for now. See Zig code for how it is autogen'd

type WordsDictionary = HashMap<String, Vec<String>>;

fn main() -> Result<(), Box<dyn Error>> {
    let dict = {
        let dict_filename = "../resources/dictionary_small.txt";
        let dict_path = Path::new(dict_filename);
        let dict_file = File::open(dict_path)?;
        let mut dict: HashMap<String, Vec<String>> = HashMap::new();
        for line in BufReader::new(dict_file).lines() {
            let line = line?;
            let digits = word_to_num(&line);
            if let Some(v) = dict.get_mut(&digits) {
                v.push(line)
            } else {
                dict.insert(digits, vec![line]);
            }
        }
        dict
    };
    // println!("{:?}", dict);
    let phone_num_filename = "../resources/input_small.txt";
    let phone_num_path = Path::new(phone_num_filename);
    let phone_num_file = File::open(phone_num_path)?;
    for phone_num in BufReader::new(phone_num_file).lines() {
        let phone_num = phone_num?;
        // for each phone number, print the translation.
        print_translation(&phone_num, &dict);
    }

    Ok(())
}

fn print_translation(phone_number: &str, dict: &WordsDictionary) {
    // helper function that does the real work recursively
    fn helper(
        word_list: &mut Vec<String>,
        start: usize,
        phone_number: &str,
        digits: &str,
        dict: &WordsDictionary,
    ) {
        if start >= digits.len() {
            // Base case, print everything in word_list and end the recursion
            // pretty print it for now
            print!("{}:", phone_number);
            for word in word_list {
                print!(" {}", word);
            }
            println!();
            return;
        }
        let mut found_word = false;
        // The key is comprised of [start, end)
        // e.g. digits: 5  6  2  4  8  2
        // start: 3              ^
        // end: [4, 5, 6]
        for end in (start + 1)..=digits.len() {
            let key = &digits[start..end];
            // println!("Searching for key {}", key);
            if let Some(words_mapped_to_digit) = dict.get(key) {
                found_word = true;
                for word in words_mapped_to_digit {
                    // Recurse. Push onto word_list before recursion, and pop after.
                    word_list.push(word.to_string());
                    helper(word_list, end, phone_number, digits, dict);
                    let x = word_list.pop(); // ignore the popped value
                    debug_assert!(x.is_some());
                }
            }
        }
        if !found_word && is_empty_or_last_elt_is_not_single_digit(word_list) {
            let single_digit = (digits.as_bytes()[start] as char).to_string();

            word_list.push(single_digit);
            helper(word_list, start + 1, phone_number, digits, dict);
            let x = word_list.pop(); // ignore the popped value
            debug_assert!(x.is_some());
        }
    }

    let digits = only_digits(phone_number);
    let mut word_list = Vec::new();
    helper(&mut word_list, 0, phone_number, &digits, dict);
}

/// Name says it all.
fn is_empty_or_last_elt_is_not_single_digit(v: &[String]) -> bool {
    v.last().map_or(true, |s| s.len() != 1)
}

fn word_to_num(word: &str) -> String {
    word.bytes()
        .filter(u8::is_ascii_alphabetic)
        .map(|c| DIGIT_MAP[(c.to_ascii_lowercase() - b'a') as usize] as char)
        .collect()
}

fn only_digits(word: &str) -> String {
    word.chars().filter(char::is_ascii_digit).collect()
}

/*
DIGIT_MAP was generated using this Zig code:

```zig
fn createDigitMap() [26]u8 {
    var result: [26]u8 = undefined;
    result['e' - 'a'] = '0';
    result['j' - 'a'] = '1'; result['n' - 'a'] = '1'; result['q' - 'a'] = '1';
    result['r' - 'a'] = '2'; result['w' - 'a'] = '2'; result['x' - 'a'] = '2';
    result['d' - 'a'] = '3'; result['s' - 'a'] = '3'; result['y' - 'a'] = '3';
    result['f' - 'a'] = '4'; result['t' - 'a'] = '4';
    result['a' - 'a'] = '5'; result['m' - 'a'] = '5';
    result['c' - 'a'] = '6'; result['i' - 'a'] = '6'; result['v' - 'a'] = '6';
    result['b' - 'a'] = '7'; result['k' - 'a'] = '7'; result['u' - 'a'] = '7';
    result['l' - 'a'] = '8'; result['o' - 'a'] = '8'; result['p' - 'a'] = '8';
    result['g' - 'a'] = '9'; result['h' - 'a'] = '9'; result['z' - 'a'] = '9';
    return result;
}

const std = @import("std");

pub fn main() void {
    std.debug.print("{any}", .{createDigitMap()});
}
```
*/
