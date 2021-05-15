use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::Path;
use std::{char::MAX, collections::HashMap};

const DIGIT_MAP: [u8; 26] = [
    53, 55, 54, 51, 48, 52, 57, 57, 54, 49, 55, 56, 53, 49, 56, 56, 49, 50, 51, 52, 55, 54, 50, 50,
    51, 57,
]; // auto gen-ed for now. See Zig code for how it is autogen'd

fn main() -> Result<(), io::Error> {
    let dict = {
        let dict_filename = "../resources/dictionary_small.txt";
        let dict_path = Path::new(dict_filename);
        let dict_file = File::open(dict_path)?;
        let mut dict: HashMap<String, Vec<String>> = HashMap::new();
        for line in BufReader::new(dict_file).lines() {
            // println!("{:?}", line.unwrap());
            let line = line.expect("line should be nonempty");
            let digits = word_to_num(&line.as_bytes());
            match dict.get_mut(&digits) {
                Some(v) => v.push(line),
                None => {
                    let v = vec![line];
                    dict.insert(digits, v);
                }
            }
        }
        dict
    };
    println!("{:?}", dict);
    // let phone_num_filename = "../resources/input_small.txt";
    Ok(())
}

fn word_to_num(word: &[u8]) -> String {
    word.iter()
        .filter(|c| c.is_ascii_alphabetic())
        .map(|c| DIGIT_MAP[(c.to_ascii_lowercase() - b'a') as usize] as char)
        .collect()
}

fn only_digits(word: &[u8]) -> String {
    word.iter()
        .filter(|c| c.is_ascii_digit())
        .map(|c| *c as char)
        .collect()
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
