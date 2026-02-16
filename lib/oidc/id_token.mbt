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
/// Parse an ID Token from a JWT string
pub fn IdToken::parse(
  token_string : String,
) -> Result[IdToken, @oauth2.OAuth2Error] {
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
fn split_jwt(
  jwt : String,
) -> Result[(String, String, String), @oauth2.OAuth2Error] {
  let parts_iter = jwt.split(".")
  let parts = parts_iter.map(fn(sv) { sv.to_string() }).to_array()

  if parts.length() != 3 {
    return Err(
      @oauth2.OAuth2Error::new_other(
        "Invalid JWT format: expected 3 parts separated by '.'",
      ),
    )
  }

  Ok((parts[0], parts[1], parts[2]))
}

///|
/// Decode Base64URL string
fn base64url_decode(input : String) -> Result[String, @oauth2.OAuth2Error] {
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
    e =>
      return Err(
        @oauth2.OAuth2Error::new_other("Failed to decode Base64: \{e}"),
      )
  }

  // Convert bytes to UTF-8 string using encoding library
  let decoder = @encoding.decoder(@encoding.Encoding::UTF8)
  let result = decoder.decode_lossy(bytes.op_as_view())
  Ok(result)
}

///|
/// Parse JWT header from JSON string
fn parse_jwt_header(
  json_str : String,
) -> Result[JwtHeader, @oauth2.OAuth2Error] {
  let json = @json.parse(json_str) catch {
    e =>
      return Err(
        @oauth2.OAuth2Error::new_other("Failed to parse JWT header JSON: \{e}"),
      )
  }

  let obj = match json {
    Object(o) => o
    _ =>
      return Err(
        @oauth2.OAuth2Error::new_other("JWT header must be a JSON object"),
      )
  }

  let alg = match obj.get("alg") {
    Some(String(s)) => s
    Some(_) =>
      return Err(@oauth2.OAuth2Error::new_other("Invalid 'alg' in JWT header"))
    None =>
      return Err(@oauth2.OAuth2Error::new_other("Missing 'alg' in JWT header"))
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
fn parse_claims(
  json_str : String,
) -> Result[IdTokenClaims, @oauth2.OAuth2Error] {
  let json = @json.parse(json_str) catch {
    e =>
      return Err(
        @oauth2.OAuth2Error::new_other("Failed to parse claims JSON: \{e}"),
      )
  }

  let obj = match json {
    Object(o) => o
    _ =>
      return Err(@oauth2.OAuth2Error::new_other("Claims must be a JSON object"))
  }

  // Required claims
  let iss = match obj.get("iss") {
    Some(String(s)) => s
    Some(_) => return Err(@oauth2.OAuth2Error::new_other("Invalid 'iss' claim"))
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'iss' claim"))
  }

  let sub = match obj.get("sub") {
    Some(String(s)) => s
    Some(_) => return Err(@oauth2.OAuth2Error::new_other("Invalid 'sub' claim"))
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'sub' claim"))
  }

  let aud = match obj.get("aud") {
    Some(String(s)) => s
    Some(Array(arr)) if arr.length() == 0 =>
      return Err(@oauth2.OAuth2Error::new_other("Empty 'aud' array"))
    Some(Array(arr)) =>
      match arr[0] {
        String(s) => s
        _ =>
          return Err(
            @oauth2.OAuth2Error::new_other("Invalid 'aud' claim in array"),
          )
      }
    Some(_) => return Err(@oauth2.OAuth2Error::new_other("Invalid 'aud' claim"))
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'aud' claim"))
  }

  let exp = match obj.get("exp") {
    Some(Number(n, ..)) => n.to_int64()
    Some(_) => return Err(@oauth2.OAuth2Error::new_other("Invalid 'exp' claim"))
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'exp' claim"))
  }

  let iat = match obj.get("iat") {
    Some(Number(n, ..)) => n.to_int64()
    Some(_) => return Err(@oauth2.OAuth2Error::new_other("Invalid 'iat' claim"))
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'iat' claim"))
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
