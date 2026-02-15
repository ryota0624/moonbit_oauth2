///|
/// SHA256 Hash Implementation (RFC 6234)
/// Used for PKCE code_challenge computation

///|
/// SHA256 hash constants (first 32 bits of fractional parts of cube roots of first 64 primes)
let k : Array[UInt] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
]

///|
/// Initial hash values (first 32 bits of fractional parts of square roots of first 8 primes)
fn initial_hash() -> Array[UInt] {
  [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
    0x5be0cd19,
  ]
}

///|
/// Compute SHA256 hash of input string
/// Returns 32-byte (256-bit) hash as array of bytes
pub fn sha256(message : String) -> Array[UInt] {
  // Convert message to bytes
  let bytes = string_to_bytes(message)

  // Preprocess: add padding and length
  let padded = pad_message(bytes)

  // Process message in 512-bit (64-byte) blocks
  let mut hash = initial_hash()

  for i = 0; i < padded.length() / 64; i = i + 1 {
    let block = padded[i * 64:(i + 1) * 64].to_array()
    hash = process_block(block, hash)
  }

  hash
}

///|
/// Compute SHA256 and return as hex string
pub fn sha256_hex(message : String) -> String {
  let hash = sha256(message)
  let result = StringBuilder::new()
  // Each hash word is 32 bits = 4 bytes
  for i = 0; i < hash.length(); i = i + 1 {
    let word = hash[i]
    // Extract 4 bytes from 32-bit word
    result.write_string(uint_to_hex((word >> 24) & 0xFF))
    result.write_string(uint_to_hex((word >> 16) & 0xFF))
    result.write_string(uint_to_hex((word >> 8) & 0xFF))
    result.write_string(uint_to_hex(word & 0xFF))
  }
  result.to_string()
}

///|
/// Convert string to array of bytes (UInt values 0-255)
fn string_to_bytes(s : String) -> Array[UInt] {
  let bytes : Array[UInt] = []
  for i = 0; i < s.length(); i = i + 1 {
    bytes.push(s[i].to_int().reinterpret_as_uint())
  }
  bytes
}

///|
/// Pad message according to SHA256 specification
/// Padding: message + 0x80 + zeros + length (64-bit big-endian)
fn pad_message(bytes : Array[UInt]) -> Array[UInt] {
  let original_length = bytes.length() * 8 // in bits

  // Create padded message
  let padded : Array[UInt] = []
  for i = 0; i < bytes.length(); i = i + 1 {
    padded.push(bytes[i])
  }

  // Append 0x80
  padded.push(0x80)

  // Append zeros until length ≡ 448 (mod 512)
  // We need (current_length + 64) to be multiple of 512
  while (padded.length() * 8 + 64) % 512 != 0 {
    padded.push(0)
  }

  // Append original length as 64-bit big-endian
  // For simplicity, we only handle lengths that fit in 32 bits
  padded.push(0) // upper 32 bits
  padded.push(0)
  padded.push(0)
  padded.push(0)
  padded.push(((original_length >> 24) % 256).reinterpret_as_uint())
  padded.push(((original_length >> 16) % 256).reinterpret_as_uint())
  padded.push(((original_length >> 8) % 256).reinterpret_as_uint())
  padded.push((original_length % 256).reinterpret_as_uint())

  padded
}

///|
/// Process a single 512-bit (64-byte) block
fn process_block(block : Array[UInt], hash : Array[UInt]) -> Array[UInt] {
  // Create message schedule (64 words)
  let w : Array[UInt] = Array::make(64, 0)

  // First 16 words are from the block (big-endian 32-bit words)
  for i = 0; i < 16; i = i + 1 {
    let word = (block[i * 4] << 24) |
      (block[i * 4 + 1] << 16) |
      (block[i * 4 + 2] << 8) |
      block[i * 4 + 3]
    w[i] = word
  }

  // Extend the first 16 words into the remaining 48 words
  for i = 16; i < 64; i = i + 1 {
    let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
    let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
    w[i] = w[i - 16] + s0 + w[i - 7] + s1
  }

  // Initialize working variables
  let mut a = hash[0]
  let mut b = hash[1]
  let mut c = hash[2]
  let mut d = hash[3]
  let mut e = hash[4]
  let mut f = hash[5]
  let mut g = hash[6]
  let mut h = hash[7]

  // Main loop (64 rounds)
  for i = 0; i < 64; i = i + 1 {
    let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
    let ch = (e & f) ^ (e.lnot() & g)
    let temp1 = h + s1 + ch + k[i] + w[i]
    let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
    let maj = (a & b) ^ (a & c) ^ (b & c)
    let temp2 = s0 + maj

    h = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }

  // Add compressed chunk to current hash value
  [
    hash[0] + a,
    hash[1] + b,
    hash[2] + c,
    hash[3] + d,
    hash[4] + e,
    hash[5] + f,
    hash[6] + g,
    hash[7] + h,
  ]
}

///|
/// Right rotate (circular shift)
fn rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

///|
/// Convert UInt to 2-digit hex string (for bytes 0-255)
fn uint_to_hex(n : UInt) -> String {
  let hex_chars = "0123456789abcdef"
  let high = n / 16 % 16
  let low = n % 16
  let result = StringBuilder::new()
  result.write_char(hex_chars[high.reinterpret_as_int()].unsafe_to_char())
  result.write_char(hex_chars[low.reinterpret_as_int()].unsafe_to_char())
  result.to_string()
}
