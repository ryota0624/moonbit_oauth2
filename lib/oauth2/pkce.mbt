///|
/// PKCE (Proof Key for Code Exchange) Implementation
/// RFC 7636: https://datatracker.ietf.org/doc/html/rfc7636

///|
/// PKCE code_verifier
/// A cryptographically random string between 43 and 128 characters
pub struct PkceCodeVerifier {
  value : String
} derive(Show, Eq)

///|
/// PKCE code_challenge
/// Derived from code_verifier using S256 (SHA256) or Plain method
pub struct PkceCodeChallenge {
  value : String
  method : PkceCodeChallengeMethod
} derive(Show, Eq)

///|
/// PKCE code_challenge_method
pub enum PkceCodeChallengeMethod {
  Plain // code_challenge = code_verifier
  S256 // code_challenge = BASE64URL(SHA256(code_verifier))
} derive(Show, Eq)

///|
/// Create a new PkceCodeVerifier from an existing string
/// The string must be 43-128 characters long and contain only unreserved characters
pub fn PkceCodeVerifier::new(value : String) -> PkceCodeVerifier {
  { value, }
}

///|
/// Generate a random PKCE code_verifier
/// Returns a 43-character string (256 bits of entropy)
/// Uses cryptographically secure random number generator (Chacha8 CSPRNG)
/// Characters: A-Z, a-z, 0-9, -, ., _, ~
pub fn PkceCodeVerifier::new_random() -> PkceCodeVerifier {
  // Generate 43 random characters from unreserved character set
  // RFC 7636 recommends 43-128 characters, we use 43 (minimum)
  let r = @random.Rand::new()
  let unreserved_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  let char_count = unreserved_chars.length()
  let result = StringBuilder::new()

  for i = 0; i < 43; i = i + 1 {
    let idx = r
      .uint(limit=char_count.reinterpret_as_uint())
      .reinterpret_as_int()
    result.write_char(unreserved_chars[idx].unsafe_to_char())
  }

  { value: result.to_string() }
}

///|
/// Get the string value of code_verifier
pub fn PkceCodeVerifier::to_string(self : PkceCodeVerifier) -> String {
  self.value
}

///|
/// Create a PkceCodeChallenge from a code_verifier
/// Uses S256 method (SHA256 hash + Base64URL encoding)
pub fn PkceCodeChallenge::from_verifier_s256(
  verifier : PkceCodeVerifier,
) -> PkceCodeChallenge {
  // Compute SHA256 hash of code_verifier
  let hash_words = sha256(verifier.value)

  // Convert hash words (8 x 32-bit) to bytes (32 x 8-bit)
  let hash_bytes = StringBuilder::new()
  for i = 0; i < hash_words.length(); i = i + 1 {
    let word = hash_words[i]
    // Extract 4 bytes from each 32-bit word and convert to Char
    hash_bytes.write_char(
      ((word >> 24) & 0xFF).reinterpret_as_int().unsafe_to_char(),
    )
    hash_bytes.write_char(
      ((word >> 16) & 0xFF).reinterpret_as_int().unsafe_to_char(),
    )
    hash_bytes.write_char(
      ((word >> 8) & 0xFF).reinterpret_as_int().unsafe_to_char(),
    )
    hash_bytes.write_char((word & 0xFF).reinterpret_as_int().unsafe_to_char())
  }

  // Base64URL encode the hash
  let challenge_value = base64url_encode(hash_bytes.to_string())

  { value: challenge_value, method: S256 }
}

///|
/// Create a PkceCodeChallenge using Plain method
/// code_challenge = code_verifier (not recommended, use S256 instead)
pub fn PkceCodeChallenge::from_verifier_plain(
  verifier : PkceCodeVerifier,
) -> PkceCodeChallenge {
  { value: verifier.value, method: Plain }
}

///|
/// Get the string value of code_challenge
pub fn PkceCodeChallenge::to_string(self : PkceCodeChallenge) -> String {
  self.value
}

///|
/// Get the code_challenge_method as a string
pub fn PkceCodeChallenge::method_string(self : PkceCodeChallenge) -> String {
  match self.method {
    Plain => "plain"
    S256 => "S256"
  }
}
