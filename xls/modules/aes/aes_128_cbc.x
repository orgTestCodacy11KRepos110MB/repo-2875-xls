// Copyright 2022 The XLS Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Implementation of the AES-128 cipher, using cipher block chaining.
// TODO(rspringer): Complete the implementation.

const KEY_BITS = u32:128;
const KEY_WORD_BITS = u32:32;
const KEY_WORDS = KEY_BITS / KEY_WORD_BITS;

const NUM_ROUNDS = u32:10;

type KeyWord = u32;
type Key = KeyWord[KEY_WORDS];
type KeySchedule = Key[NUM_ROUNDS + u32:1];

// The Rijndael S-box.
const S_BOX = u8[256]:[
    u8:0x63, u8:0x7c, u8:0x77, u8:0x7b, u8:0xf2, u8:0x6b, u8:0x6f, u8:0xc5,
    u8:0x30, u8:0x01, u8:0x67, u8:0x2b, u8:0xfe, u8:0xd7, u8:0xab, u8:0x76,
    u8:0xca, u8:0x82, u8:0xc9, u8:0x7d, u8:0xfa, u8:0x59, u8:0x47, u8:0xf0,
    u8:0xad, u8:0xd4, u8:0xa2, u8:0xaf, u8:0x9c, u8:0xa4, u8:0x72, u8:0xc0,
    u8:0xb7, u8:0xfd, u8:0x93, u8:0x26, u8:0x36, u8:0x3f, u8:0xf7, u8:0xcc,
    u8:0x34, u8:0xa5, u8:0xe5, u8:0xf1, u8:0x71, u8:0xd8, u8:0x31, u8:0x15,
    u8:0x04, u8:0xc7, u8:0x23, u8:0xc3, u8:0x18, u8:0x96, u8:0x05, u8:0x9a,
    u8:0x07, u8:0x12, u8:0x80, u8:0xe2, u8:0xeb, u8:0x27, u8:0xb2, u8:0x75,
    u8:0x09, u8:0x83, u8:0x2c, u8:0x1a, u8:0x1b, u8:0x6e, u8:0x5a, u8:0xa0,
    u8:0x52, u8:0x3b, u8:0xd6, u8:0xb3, u8:0x29, u8:0xe3, u8:0x2f, u8:0x84,
    u8:0x53, u8:0xd1, u8:0x00, u8:0xed, u8:0x20, u8:0xfc, u8:0xb1, u8:0x5b,
    u8:0x6a, u8:0xcb, u8:0xbe, u8:0x39, u8:0x4a, u8:0x4c, u8:0x58, u8:0xcf,
    u8:0xd0, u8:0xef, u8:0xaa, u8:0xfb, u8:0x43, u8:0x4d, u8:0x33, u8:0x85,
    u8:0x45, u8:0xf9, u8:0x02, u8:0x7f, u8:0x50, u8:0x3c, u8:0x9f, u8:0xa8,
    u8:0x51, u8:0xa3, u8:0x40, u8:0x8f, u8:0x92, u8:0x9d, u8:0x38, u8:0xf5,
    u8:0xbc, u8:0xb6, u8:0xda, u8:0x21, u8:0x10, u8:0xff, u8:0xf3, u8:0xd2,
    u8:0xcd, u8:0x0c, u8:0x13, u8:0xec, u8:0x5f, u8:0x97, u8:0x44, u8:0x17,
    u8:0xc4, u8:0xa7, u8:0x7e, u8:0x3d, u8:0x64, u8:0x5d, u8:0x19, u8:0x73,
    u8:0x60, u8:0x81, u8:0x4f, u8:0xdc, u8:0x22, u8:0x2a, u8:0x90, u8:0x88,
    u8:0x46, u8:0xee, u8:0xb8, u8:0x14, u8:0xde, u8:0x5a, u8:0x0b, u8:0xdb,
    u8:0xe0, u8:0x32, u8:0x3a, u8:0x0a, u8:0x49, u8:0x06, u8:0x24, u8:0x5c,
    u8:0xc2, u8:0xd3, u8:0xac, u8:0x62, u8:0x91, u8:0x95, u8:0xe4, u8:0x79,
    u8:0xe7, u8:0xc8, u8:0x37, u8:0x6d, u8:0x8d, u8:0xd5, u8:0x4e, u8:0xa9,
    u8:0x6c, u8:0x56, u8:0xf4, u8:0xea, u8:0x65, u8:0x7a, u8:0xae, u8:0x08,
    u8:0xba, u8:0x78, u8:0x25, u8:0x2e, u8:0x1c, u8:0xa6, u8:0xb4, u8:0xc6,
    u8:0xe8, u8:0xdd, u8:0x74, u8:0x1f, u8:0x4b, u8:0xbd, u8:0x8b, u8:0x8a,
    u8:0x70, u8:0x3e, u8:0xb5, u8:0x66, u8:0x48, u8:0x03, u8:0xf6, u8:0x0e,
    u8:0x61, u8:0x35, u8:0x57, u8:0xb9, u8:0x86, u8:0xc1, u8:0x1d, u8:0x9e,
    u8:0xe1, u8:0xf8, u8:0x98, u8:0x11, u8:0x69, u8:0xd9, u8:0x8e, u8:0x94,
    u8:0x9b, u8:0x1e, u8:0x87, u8:0xe9, u8:0xce, u8:0x55, u8:0x28, u8:0xdf,
    u8:0x8c, u8:0xa1, u8:0x89, u8:0x0d, u8:0xbf, u8:0xe6, u8:0x42, u8:0x68,
    u8:0x41, u8:0x99, u8:0x2d, u8:0x0f, u8:0xb0, u8:0x54, u8:0xbb, u8:0x16];

// The AES round constants; hardcoded rather than derived.
const R_CON = u32[10]:[0x01000000, 0x02000000, 0x04000000, 0x08000000,
                       0x10000000, 0x20000000, 0x40000000, 0x80000000,
                       0x1b000000, 0x36000000];

fn rot_word(word: KeyWord) -> KeyWord {
    let bytes = word as u8[4];
    let bytes = u8[4]:[bytes[1], bytes[2], bytes[3], bytes[0]];
    bytes as KeyWord
}

fn sub_word(word: KeyWord) -> KeyWord {
    let bytes = word as u8[4];
    let bytes = u8[4]:[S_BOX[bytes[0]], S_BOX[bytes[1]], S_BOX[bytes[2]], S_BOX[bytes[3]]];
    bytes as KeyWord
}

// Creates the set of keys used for each [of the 9] rounds of encryption.
pub fn create_key_schedule(key : Key) -> KeySchedule {
    let sched = KeySchedule:[key, ... ];
    let (sched, _) = for (round, (sched, last_word)) : (u32, (KeySchedule, KeyWord))
                                                        in range(u32:1, NUM_ROUNDS + u32:1) {
        let word0 = sched[round - u32:1][0] ^ sub_word(rot_word(last_word)) ^ R_CON[round - 1];
        let word1 = sched[round - u32:1][1] ^ word0;
        let word2 = sched[round - u32:1][2] ^ word1;
        let word3 = sched[round - u32:1][3] ^ word2;
        let sched = update(sched, round, Key:[word0, word1, word2, word3]);
        (sched, word3)
    }((sched, sched[0][3]));
    sched
}

// Produces a key whose bytes are in the reverse order as the incoming byte stream,
// e.g.,
// "abcd..." (i.e., 0x61, 0x62, 0x63, 0x64...) -> [0x64636261, ...]
pub fn string_to_key(input: u8[16]) -> Key {
    Key:[input[15] ++ input[14] ++ input[13] ++ input[12],
         input[11] ++ input[10] ++ input[9] ++ input[8],
         input[7] ++ input[6] ++ input[5] ++ input[4],
         input[3] ++ input[2] ++ input[1] ++ input[0]]
}

// Produces a key whose bytes are in the same order as the incoming byte stream,
// e.g.,
// "abcd..." (i.e., 0x61, 0x62, 0x63, 0x64...) -> [0x61626364, ...]
pub fn bytes_to_key(bytes: u8[16]) -> Key {
    Key:[bytes[0] ++ bytes[1] ++ bytes[2] ++ bytes[3],
         bytes[4] ++ bytes[5] ++ bytes[6] ++ bytes[7],
         bytes[8] ++ bytes[9] ++ bytes[10] ++ bytes[11],
         bytes[12] ++ bytes[13] ++ bytes[14] ++ bytes[15]]
}

fn trace_key(key: Key) {
    let bytes0 = key[0] as u8[4];
    let bytes1 = key[1] as u8[4];
    let bytes2 = key[2] as u8[4];
    let bytes3 = key[3] as u8[4];
    let _ = trace_fmt!(
        "{:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x} {:x}",
        bytes0[0], bytes0[1], bytes0[2], bytes0[3],
        bytes1[0], bytes1[1], bytes1[2], bytes1[3],
        bytes2[0], bytes2[1], bytes2[2], bytes2[3],
        bytes3[0], bytes3[1], bytes3[2], bytes3[3]);
    ()
}

// Verifies we produce a correct schedule for a given input key.
// Verification values were generated from from the BoringSSL implementation,
// commit efd09b7e.
#![test]
fn test_key_schedule() {
    let key = string_to_key("0123456789abcdef");
    let sched = create_key_schedule(key);
    let _ = assert_eq(sched[0], key);
    let _ = assert_eq(
        sched[1],
        bytes_to_key(
            u8[16]:[u8:0x44, u8:0xa2, u8:0x60, u8:0xa0, u8:0x26, u8:0xc3, u8:0x59, u8:0x98,
                    u8:0x11, u8:0xf5, u8:0x6c, u8:0xac, u8:0x22, u8:0xc7, u8:0x5d, u8:0x9c]));
    let _ = assert_eq(
        sched[2],
        bytes_to_key(
            u8[16]:[u8:0x80, u8:0xee, u8:0xbe, u8:0x33, u8:0xa6, u8:0x2d, u8:0xe7, u8:0xab,
                    u8:0xb7, u8:0xd8, u8:0x8b, u8:0x07, u8:0x95, u8:0x1f, u8:0xd6, u8:0x9b]));
    // Since round key N depends on round key N-1, we'll just jump ahead to
    // the last one.
    let _ = assert_eq(
        sched[10],
        bytes_to_key(
            u8[16]:[u8:0x71, u8:0x21, u8:0x06, u8:0xf1, u8:0x59, u8:0xd1, u8:0x69, u8:0x25,
                    u8:0x03, u8:0x21, u8:0xe7, u8:0xaa, u8:0xb9, u8:0xae, u8:0x62, u8:0xe0]));
    ()
}
