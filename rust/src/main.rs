//! A Rust translation of [Norvig's Lisp as an alternative to Java](https://norvig.com/java-lisp.html).
//! This is a fun little exercise that I use when learning a new language.
//! I've done this previous excursion in Zig, Nim and Clojure and Python [Github link](https://github.com/thomastay/phone-numbers-words)
//!
//! The gist of this problem is as such: Given some mapping of letters to digits,
//! we want to "translate" a phone number into a series of words that encode the phone number
//! The words will be given to us via some dictionary.
//!
//! [The full instructions are here](https://github.com/thomastay/phone-numbers-words/blob/master/resources/test_instructions.txt)
//!
//! For instance, given the mapping below, and a dictionary of words:
//! MAPPING:
//! ```
//!       E | J N Q | R W X | D S Y | F T | A M | C I V | B K U | L O P | G H Z
//!       e | j n q | r w x | d s y | f t | a m | c i v | b k u | l o p | g h z
//!       0 |   1   |   2   |   3   |  4  |  5  |   6   |   7   |   8   |   9
//! ```
//! DICT: `{ hell, hello, o, world, row, oy }`
//! we might encode the number 908-882-8283 in 4 different ways:
//!    1. hello world
//!    2. hell o world
//!    3. hello row oy
//!    4. hell o row oy

#![deny(missing_docs)]
#![deny(rust_2018_idioms)]
#![deny(clippy::too_many_arguments)]
#![deny(clippy::complexity)]
#![deny(clippy::perf)]
#![forbid(unsafe_code)]
#![warn(clippy::style)]
#![warn(clippy::pedantic)]

use std::{
    collections::HashMap,
    env,
    error::Error,
    fs::File,
    io::{BufRead, BufReader},
    path::Path,
    process::exit,
};

const DIGIT_MAP: [u8; 26] = [
    53, 55, 54, 51, 48, 52, 57, 57, 54, 49, 55, 56, 53, 49, 56, 56, 49, 50, 51, 52, 55, 54, 50, 50,
    51, 57,
]; // auto gen-ed for now. See bottom of file for how it is autogen'd

type WordsDictionary = HashMap<String, Vec<String>>;

fn main() -> Result<(), Box<dyn Error>> {
    let args = env::args().skip(1).collect::<Vec<_>>();
    if args.len() != 2 {
        eprintln!("Usage: ./phone_number_words <dict filename> <input filename>");
        exit(1); // Note: was annoying that String does not implement the error trait.
    }
    let dict_filename = &args[0];
    let phone_num_filename = &args[1];

    let dict = read_dict_from_file(dict_filename)?;
    let phone_num_path = Path::new(phone_num_filename);
    let phone_num_file = File::open(phone_num_path)?;
    for phone_num in BufReader::new(phone_num_file).lines() {
        let phone_num = phone_num?;
        // for each phone number, print the translation.
        print_translation(&phone_num, &dict);
    }
    Ok(())
}

fn read_dict_from_file(dict_filename: &str) -> Result<WordsDictionary, Box<dyn Error>> {
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
    Ok(dict)
}

/// For a given phone number and a dictionary mapping digits to phone numbers,
/// prints the phone number and all combinations of words that might encode the phone number.
fn print_translation(phone_number: &str, dict: &WordsDictionary) {
    // helper function that does the real work recursively
    fn helper<'d>(
        word_list: &mut Vec<&'d str>,
        start: usize,
        phone_number: &str,
        digits: &'d str,
        dict: &'d WordsDictionary,
    ) {
        if start >= digits.len() {
            // Base case, print everything in word_list and end the recursion
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
        // TODO make this slicing better, probably.
        for end in (start + 1)..=digits.len() {
            let key = &digits[start..end];
            if let Some(words_mapped_to_digit) = dict.get(key) {
                found_word = true;
                for word in words_mapped_to_digit {
                    // Recurse. Push onto word_list before recursion, and pop after.
                    word_list.push(word);
                    helper(word_list, end, phone_number, digits, dict);
                    let last = word_list.pop();
                    // Sanity check: upon reaching this point, the last elt of the vec should be the one
                    // we just pushed on.
                    debug_assert_eq!(last, Some(String::as_str(word)));
                }
            }
        }
        if !found_word && is_empty_or_last_elt_is_not_single_digit(word_list) {
            let single_digit = &digits[start..=start];
            // Recurse. Push onto word_list before recursion, and pop after.
            word_list.push(single_digit);
            helper(word_list, start + 1, phone_number, digits, dict);
            let last = word_list.pop();
            // Sanity check: upon reaching this point, the last elt of the vec should be the one
            // we just pushed on.
            debug_assert_eq!(last, Some(&digits[start..=start]));
        }
    }

    let digits = only_digits(phone_number);
    let mut word_list = Vec::new();
    helper(&mut word_list, 0, phone_number, &digits, dict);
}

fn is_empty_or_last_elt_is_not_single_digit(v: &[&str]) -> bool {
    v.last().map_or(true, |s| s.len() != 1)
}

/// e.g. helloworld --> 9088828283
fn word_to_num(word: &str) -> String {
    word.bytes()
        .filter(u8::is_ascii_alphabetic)
        .map(|c| DIGIT_MAP[(c.to_ascii_lowercase() - b'a') as usize] as char)
        .collect()
}

/// e.g. 908-882/8283 --> 9088828283
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
