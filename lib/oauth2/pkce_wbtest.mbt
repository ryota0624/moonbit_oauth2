///|
/// Tests for PKCE (Proof Key for Code Exchange)

///|
test "PkceCodeVerifier::new" {
  let verifier = PkceCodeVerifier::new(
    "test_verifier_12345678901234567890123456",
  )
  assert_eq(verifier.value, "test_verifier_12345678901234567890123456")
}

///|
test "PkceCodeVerifier::new_random generates valid verifier" {
  let verifier = PkceCodeVerifier::new_random()
  let value = verifier.to_string()

  // Should be exactly 43 characters
  assert_eq(value.length(), 43)

  // Should only contain unreserved characters
  // A-Z, a-z, 0-9, -, ., _, ~
  for i = 0; i < value.length(); i = i + 1 {
    let ch = value[i].to_int()
    let is_valid = (ch >= 65 && ch <= 90) ||
      (ch >= 97 && ch <= 122) ||
      (ch >= 48 && ch <= 57) ||
      ch == 45 ||
      ch == 46 ||
      ch == 95 ||
      ch == 126
    assert_true(is_valid)
  }
}

///|
test "PkceCodeVerifier::new_random generates different values" {
  let verifier1 = PkceCodeVerifier::new_random()
  let verifier2 = PkceCodeVerifier::new_random()

  // Should generate different values (not guaranteed but very likely)
  assert_true(verifier1.to_string().length() == 43)
  assert_true(verifier2.to_string().length() == 43)
}

///|
test "PkceCodeChallenge::from_verifier_s256" {
  // Use a known verifier to test S256 challenge
  let verifier = PkceCodeVerifier::new(
    "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
  )
  let challenge = PkceCodeChallenge::from_verifier_s256(verifier)

  // Challenge should be Base64URL encoded SHA256 hash
  assert_eq(challenge.method, S256)

  // Should be a valid Base64URL string (no + / =)
  let value = challenge.to_string()
  assert_false(value.contains("+"))
  assert_false(value.contains("/"))
  assert_false(value.contains("="))

  // Should have reasonable length (43 characters for Base64URL of 32-byte SHA256)
  assert_true(value.length() == 43) // 256 bits = 32 bytes -> 43 chars in Base64URL
}

///|
test "PkceCodeChallenge::from_verifier_s256 RFC example" {
  // RFC 7636 Appendix B example
  let verifier = PkceCodeVerifier::new(
    "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
  )
  let challenge = PkceCodeChallenge::from_verifier_s256(verifier)

  // Expected challenge from RFC 7636
  let expected = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
  assert_eq(challenge.to_string(), expected)
}

///|
test "PkceCodeChallenge::from_verifier_plain" {
  let verifier = PkceCodeVerifier::new("test_verifier_value")
  let challenge = PkceCodeChallenge::from_verifier_plain(verifier)

  // Plain method: challenge = verifier
  assert_eq(challenge.to_string(), "test_verifier_value")
  assert_eq(challenge.method, Plain)
}

///|
test "PkceCodeChallenge::method_string" {
  let verifier = PkceCodeVerifier::new("test")

  let challenge_s256 = PkceCodeChallenge::from_verifier_s256(verifier)
  assert_eq(challenge_s256.method_string(), "S256")

  let challenge_plain = PkceCodeChallenge::from_verifier_plain(verifier)
  assert_eq(challenge_plain.method_string(), "plain")
}

///|
test "PkceCodeVerifier equality" {
  let verifier1 = PkceCodeVerifier::new("same_value")
  let verifier2 = PkceCodeVerifier::new("same_value")
  let verifier3 = PkceCodeVerifier::new("different_value")

  assert_eq(verifier1, verifier2)
  assert_true(verifier1 != verifier3)
}

///|
test "PkceCodeChallenge equality" {
  let verifier = PkceCodeVerifier::new("test")

  let challenge1 = PkceCodeChallenge::from_verifier_s256(verifier)
  let challenge2 = PkceCodeChallenge::from_verifier_s256(verifier)
  let challenge3 = PkceCodeChallenge::from_verifier_plain(verifier)

  assert_eq(challenge1, challenge2)
  assert_true(challenge1 != challenge3) // Different methods
}
