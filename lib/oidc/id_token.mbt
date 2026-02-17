///| ID Token Type Definitions and Parsing

///|
/// IdToken represents an OpenID Connect ID Token (JWT format)
pub struct IdToken {
  raw : String // Original JWT string
  header : JwtHeader
  payload : IdTokenClaims
  signature : String
} derive(Show)

///|
/// JwtHeader represents the JWT header
pub struct JwtHeader {
  alg : String // Signature algorithm (e.g., "RS256")
  typ : String // Token type (usually "JWT")
  kid : String? // Key ID (optional)
} derive(Show, Eq)

///|
/// IdTokenClaims represents the standard OIDC claims in an ID Token
pub struct IdTokenClaims {
  // Required claims
  iss : String // Issuer URL
  sub : String // Subject (user ID)
  aud : String // Audience (client ID)
  exp : Int64 // Expiration (UNIX timestamp)
  iat : Int64 // Issued At (UNIX timestamp)

  // Recommended claims
  auth_time : Int64? // Authentication time
  nonce : String? // Nonce for replay attack protection

  // Optional claims
  name : String?
  given_name : String?
  family_name : String?
  email : String?
  email_verified : Bool?
  picture : String?
  locale : String?
} derive(Show)

///|
/// IdTokenError represents errors that occur during ID Token parsing
pub enum IdTokenError {
  InvalidFormat(String) // JWT format validation failed
  Base64DecodeError(String) // Base64URL decoding failed
  InvalidJson(String) // JSON parsing failed
  InvalidStructure(String) // Structure validation failed
  InvalidFieldType(String) // Field has wrong type
  MissingRequiredField(String) // Required field is missing
  MissingIdToken // ID Token not present in response
} derive(Show, Eq)

///|
/// Convert IdTokenError to string message
pub fn IdTokenError::message(self : IdTokenError) -> String {
  match self {
    InvalidFormat(msg) => "Invalid JWT format: \{msg}"
    Base64DecodeError(msg) => "Base64 decode error: \{msg}"
    InvalidJson(msg) => "Failed to parse JSON: \{msg}"
    InvalidStructure(msg) => "Invalid structure: \{msg}"
    InvalidFieldType(msg) => "Invalid field type: \{msg}"
    MissingRequiredField(msg) => "Missing required field: \{msg}"
    MissingIdToken => "ID Token not present in response"
  }
}

///|
/// Parse an ID Token from a JWT string
pub fn IdToken::parse(token_string : String) -> Result[IdToken, IdTokenError] {
  // Split JWT into three parts: header.payload.signature
  let (header_b64, payload_b64, signature_b64) = match split_jwt(token_string) {
    Ok(parts) => parts
    Err(e) => return Err(e)
  }

  // Decode Base64URL
  let header_json = match base64url_decode(header_b64) {
    Ok(json) => json
    Err(e) => return Err(e)
  }
  let payload_json = match base64url_decode(payload_b64) {
    Ok(json) => json
    Err(e) => return Err(e)
  }

  // Parse JSON
  let header = match parse_jwt_header(header_json) {
    Ok(h) => h
    Err(e) => return Err(e)
  }
  let claims = match parse_claims(payload_json) {
    Ok(c) => c
    Err(e) => return Err(e)
  }

  Ok({ raw: token_string, header, payload: claims, signature: signature_b64 })
}

///|
/// Split JWT string into three parts (header, payload, signature)
fn split_jwt(jwt : String) -> Result[(String, String, String), IdTokenError] {
  let parts_iter = jwt.split(".")
  let parts = parts_iter.map(fn(sv) { sv.to_string() }).to_array()

  if parts.length() != 3 {
    return Err(InvalidFormat("expected 3 parts separated by '.'"))
  }

  Ok((parts[0], parts[1], parts[2]))
}

///|
/// Decode Base64URL string
fn base64url_decode(input : String) -> Result[String, IdTokenError] {
  // Base64URL uses '-' and '_' instead of '+' and '/'
  // and doesn't use padding '='
  let normalized = input.replace(old="-", new="+").replace(old="_", new="/")

  // Add padding if necessary
  let padding_needed = (4 - normalized.length() % 4) % 4
  let padded = if padding_needed > 0 {
    normalized + "=".repeat(padding_needed)
  } else {
    normalized
  }

  // Decode using standard Base64
  let bytes = @base64.decode(padded) catch {
    e => return Err(Base64DecodeError(e.to_string()))
  }

  // Convert bytes to UTF-8 string using encoding library
  let decoder = @encoding.decoder(@encoding.Encoding::UTF8)
  let result = decoder.decode_lossy(bytes.op_as_view())
  Ok(result)
}

///|
/// Parse JWT header from JSON string
fn parse_jwt_header(json_str : String) -> Result[JwtHeader, IdTokenError] {
  let json = @json.parse(json_str) catch {
    e => return Err(InvalidJson(e.to_string()))
  }

  let obj = match json {
    Object(o) => o
    _ => return Err(InvalidStructure("JWT header must be a JSON object"))
  }

  let alg = match obj.get("alg") {
    Some(String(s)) => s
    Some(_) => return Err(InvalidFieldType("'alg' must be a string"))
    None => return Err(MissingRequiredField("'alg'"))
  }

  let typ = match obj.get("typ") {
    Some(String(s)) => s
    _ => "JWT" // Default to "JWT" if not present or invalid
  }

  let kid = match obj.get("kid") {
    Some(String(s)) => Some(s)
    _ => None // None if missing or invalid type
  }

  Ok({ alg, typ, kid })
}

///|
/// Parse ID Token claims from JSON string
fn parse_claims(json_str : String) -> Result[IdTokenClaims, IdTokenError] {
  let json = @json.parse(json_str) catch {
    e => return Err(InvalidJson(e.to_string()))
  }

  let obj = match json {
    Object(o) => o
    _ => return Err(InvalidStructure("Claims must be a JSON object"))
  }

  // Required claims
  let iss = match obj.get("iss") {
    Some(String(s)) => s
    Some(_) => return Err(InvalidFieldType("'iss' must be a string"))
    None => return Err(MissingRequiredField("'iss'"))
  }

  let sub = match obj.get("sub") {
    Some(String(s)) => s
    Some(_) => return Err(InvalidFieldType("'sub' must be a string"))
    None => return Err(MissingRequiredField("'sub'"))
  }

  let aud = match obj.get("aud") {
    Some(String(s)) => s
    Some(Array(arr)) if arr.length() == 0 =>
      return Err(InvalidStructure("'aud' array cannot be empty"))
    Some(Array(arr)) =>
      match arr[0] {
        String(s) => s
        _ => return Err(InvalidFieldType("'aud' array must contain strings"))
      }
    Some(_) => return Err(InvalidFieldType("'aud' must be a string or array"))
    None => return Err(MissingRequiredField("'aud'"))
  }

  let exp = match obj.get("exp") {
    Some(Number(n, ..)) => n.to_int64()
    Some(_) => return Err(InvalidFieldType("'exp' must be a number"))
    None => return Err(MissingRequiredField("'exp'"))
  }

  let iat = match obj.get("iat") {
    Some(Number(n, ..)) => n.to_int64()
    Some(_) => return Err(InvalidFieldType("'iat' must be a number"))
    None => return Err(MissingRequiredField("'iat'"))
  }

  // Optional claims
  let auth_time = match obj.get("auth_time") {
    Some(Number(n, ..)) => Some(n.to_int64())
    _ => None
  }

  let nonce = match obj.get("nonce") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let name = match obj.get("name") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let given_name = match obj.get("given_name") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let family_name = match obj.get("family_name") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let email = match obj.get("email") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let email_verified = match obj.get("email_verified") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }

  let picture = match obj.get("picture") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let locale = match obj.get("locale") {
    Some(String(s)) => Some(s)
    _ => None
  }

  Ok({
    iss,
    sub,
    aud,
    exp,
    iat,
    auth_time,
    nonce,
    name,
    given_name,
    family_name,
    email,
    email_verified,
    picture,
    locale,
  })
}

///|
/// Get the raw JWT string
pub fn IdToken::raw(self : IdToken) -> String {
  self.raw
}

///|
/// Get the JWT header
pub fn IdToken::header(self : IdToken) -> JwtHeader {
  self.header
}

///|
/// Get the ID Token claims
pub fn IdToken::claims(self : IdToken) -> IdTokenClaims {
  self.payload
}

///|
/// Get the subject (user ID)
pub fn IdToken::subject(self : IdToken) -> String {
  self.payload.sub
}

///|
/// Get the issuer
pub fn IdToken::issuer(self : IdToken) -> String {
  self.payload.iss
}

///|
/// Get the audience
pub fn IdToken::audience(self : IdToken) -> String {
  self.payload.aud
}

///|
/// Get the expiration timestamp
pub fn IdToken::expiration(self : IdToken) -> Int64 {
  self.payload.exp
}

///|
/// Get the issued at timestamp
pub fn IdToken::issued_at(self : IdToken) -> Int64 {
  self.payload.iat
}

///|
/// Get the nonce if present
pub fn IdToken::nonce(self : IdToken) -> String? {
  self.payload.nonce
}

///|
/// Get the user's name if present
pub fn IdToken::name(self : IdToken) -> String? {
  self.payload.name
}

///|
/// Get the user's email if present
pub fn IdToken::email(self : IdToken) -> String? {
  self.payload.email
}

///|
/// VerificationError represents errors that occur during ID Token verification
pub enum VerificationError {
  TokenExpired(Int64, Int64) // (exp, current_time)
  InvalidAudience(String, String) // (expected, actual)
  InvalidIssuer(String, String) // (expected, actual)
  InvalidNonce(String, String) // (expected, actual)
  MissingNonce // Expected nonce but token has none
  SignatureVerificationNotImplemented // RS256 signature verification not yet implemented
} derive(Show, Eq)

///|
/// Convert VerificationError to string message
pub fn VerificationError::message(self : VerificationError) -> String {
  match self {
    TokenExpired(exp, now) => "ID Token has expired (exp: \{exp}, now: \{now})"
    InvalidAudience(expected, actual) =>
      "Invalid audience (expected: \{expected}, actual: \{actual})"
    InvalidIssuer(expected, actual) =>
      "Invalid issuer (expected: \{expected}, actual: \{actual})"
    InvalidNonce(expected, actual) =>
      "Invalid nonce (expected: \{expected}, actual: \{actual})"
    MissingNonce => "Expected nonce but token does not contain one"
    SignatureVerificationNotImplemented =>
      "RS256 signature verification is not yet implemented. Please verify signatures externally or use a service that provides signature verification."
  }
}

///|
/// Verify ID Token claims (expiration, audience, issuer, nonce)
///
/// This method performs validation of the ID Token claims without signature verification.
/// For production use, you MUST also verify the signature externally.
///
/// # Arguments
/// * `expected_audience` - Expected audience (client_id)
/// * `expected_issuer` - Expected issuer URL (e.g., "https://accounts.google.com")
/// * `current_time` - Current UNIX timestamp in seconds
/// * `expected_nonce` - Expected nonce (optional, checked if provided)
///
/// # Returns
/// * `Ok(())` - All claims are valid
/// * `Err(VerificationError)` - Verification failed
///
/// # Example
/// ```moonbit nocheck
/// let id_token = IdToken::parse(token_string)?
/// let current_time = 1234567890L
/// id_token.verify_claims(
///   "my-client-id",
///   "https://accounts.google.com",
///   current_time,
///   Some("random-nonce")
/// )?
/// ```
pub fn IdToken::verify_claims(
  self : IdToken,
  expected_audience : String,
  expected_issuer : String,
  current_time : Int64,
  expected_nonce : String?,
) -> Result[Unit, VerificationError] {
  // Check expiration
  if current_time >= self.payload.exp {
    return Err(TokenExpired(self.payload.exp, current_time))
  }

  // Check audience
  if self.payload.aud != expected_audience {
    return Err(InvalidAudience(expected_audience, self.payload.aud))
  }

  // Check issuer
  if self.payload.iss != expected_issuer {
    return Err(InvalidIssuer(expected_issuer, self.payload.iss))
  }

  // Check nonce if expected
  match expected_nonce {
    Some(expected) =>
      match self.payload.nonce {
        Some(actual) =>
          if actual != expected {
            return Err(InvalidNonce(expected, actual))
          }
        None => return Err(MissingNonce)
      }
    None => ()
  }

  Ok(())
}

///|
/// Verify ID Token signature using JWKS
///
/// **NOT YET IMPLEMENTED**
///
/// RS256 signature verification requires RSA cryptographic operations which are
/// not currently available in moonbitlang/x/crypto. This method returns an error
/// indicating that signature verification must be performed externally.
///
/// For production use, you MUST verify signatures using:
/// - External verification service
/// - Client-side verification in a different environment
/// - Server-side verification before passing tokens to MoonBit code
///
/// # Arguments
/// * `jwks` - JSON Web Key Set containing public keys
///
/// # Returns
/// * `Err(SignatureVerificationNotImplemented)` - Always returns this error
///
/// # Future Implementation
/// When RSA signature verification becomes available in moonbitlang/x/crypto,
/// this method will:
/// 1. Extract `kid` from JWT header
/// 2. Find matching public key in JWKS
/// 3. Verify RS256 signature
pub fn IdToken::verify_signature(
  _self : IdToken,
  _jwks : JsonWebKeySet,
) -> Result[Unit, VerificationError] {
  // TODO: Implement RS256 signature verification when crypto library supports it
  Err(SignatureVerificationNotImplemented)
}

///|
/// Verify ID Token (both signature and claims)
///
/// **WARNING**: Signature verification is not yet implemented.
/// This method currently only verifies claims. For production use,
/// you MUST verify signatures externally.
///
/// # Arguments
/// * `jwks` - JSON Web Key Set containing public keys (currently unused)
/// * `expected_audience` - Expected audience (client_id)
/// * `expected_issuer` - Expected issuer URL
/// * `current_time` - Current UNIX timestamp in seconds
/// * `expected_nonce` - Expected nonce (optional)
///
/// # Returns
/// * `Ok(())` - Claims are valid (signature not checked)
/// * `Err(VerificationError)` - Verification failed
///
/// # Example
/// ```moonbit nocheck
/// let id_token = IdToken::parse(token_string)?
/// let jwks = fetch_jwks(jwks_uri, http_client)?
/// let current_time = 1234567890L
///
/// // Note: This only verifies claims, not signature
/// id_token.verify(
///   jwks,
///   "my-client-id",
///   "https://accounts.google.com",
///   current_time,
///   None
/// )?
/// ```
pub fn IdToken::verify(
  self : IdToken,
  _jwks : JsonWebKeySet,
  expected_audience : String,
  expected_issuer : String,
  current_time : Int64,
  expected_nonce : String?,
) -> Result[Unit, VerificationError] {
  // Verify claims (signature verification skipped due to implementation limitations)
  match
    self.verify_claims(
      expected_audience, expected_issuer, current_time, expected_nonce,
    ) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  // TODO: Uncomment when signature verification is implemented
  // match self.verify_signature(jwks) {
  //   Ok(_) => ()
  //   Err(e) => return Err(e)
  // }

  Ok(())
}
