///|
/// Tests for SHA256 implementation
/// Using test vectors from RFC 6234

///|
test "sha256_hex - empty string" {
  let result = sha256_hex("")
  // Expected hash for empty string
  assert_eq(
    result, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256_hex - abc" {
  let result = sha256_hex("abc")
  // Expected hash for "abc"
  assert_eq(
    result, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256_hex - long string" {
  let input = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
  let result = sha256_hex(input)
  // Expected hash for this string
  assert_eq(
    result, "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
test "sha256_hex - simple text" {
  let result = sha256_hex("hello")
  // Expected hash for "hello"
  assert_eq(
    result, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
  )
}

///|
test "sha256_hex - The quick brown fox" {
  let result = sha256_hex("The quick brown fox jumps over the lazy dog")
  // Expected hash for this sentence
  assert_eq(
    result, "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
  )
}

///|
test "sha256 - raw bytes output" {
  let hash = sha256("abc")

  // Should return 8 32-bit words (256 bits total)
  assert_eq(hash.length(), 8)

  // First word should be 0xba7816bf for "abc"
  assert_eq(hash[0], 0xba7816bf)
}

///|
test "sha256 - multiple blocks" {
  // Test with message longer than 512 bits (64 bytes)
  // Create a string of 100 'a' characters
  let long_message = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let result = sha256_hex(long_message)

  // Should successfully hash without errors
  assert_true(result.length() == 64) // 32 bytes = 64 hex chars
}

///|
test "string_to_bytes" {
  let bytes = string_to_bytes("abc")
  assert_eq(bytes.length(), 3)
  assert_eq(bytes[0], 97) // 'a'
  assert_eq(bytes[1], 98) // 'b'
  assert_eq(bytes[2], 99) // 'c'
}

///|
test "pad_message - short message" {
  let bytes = string_to_bytes("abc")
  let padded = pad_message(bytes)

  // After padding, length should be multiple of 64 bytes (512 bits)
  assert_eq(padded.length() % 64, 0)

  // First bytes should be original message
  assert_eq(padded[0], 97) // 'a'
  assert_eq(padded[1], 98) // 'b'
  assert_eq(padded[2], 99) // 'c'

  // Next byte should be 0x80
  assert_eq(padded[3], 0x80)
}

///|
test "rotr - rotate right" {
  // Test right rotation
  let x : UInt = 0x12345678
  let rotated = rotr(x, 8)

  // Rotating 0x12345678 right by 8 bits -> 0x78123456
  assert_eq(rotated, 0x78123456)
}

///|
test "uint_to_hex" {
  assert_eq(uint_to_hex(0), "00")
  assert_eq(uint_to_hex(15), "0f")
  assert_eq(uint_to_hex(255), "ff")
  assert_eq(uint_to_hex(171), "ab") // 0xAB
}
