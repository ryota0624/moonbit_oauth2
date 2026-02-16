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
  match split_jwt(token_string) {
    Err(e) => Err(e)
    Ok((header_b64, payload_b64, signature_b64)) =>
      // Decode Base64URL
      match base64url_decode(header_b64) {
        Err(e) => Err(e)
        Ok(header_json) =>
          match base64url_decode(payload_b64) {
            Err(e) => Err(e)
            Ok(payload_json) =>
              // Parse JSON
              match parse_jwt_header(header_json) {
                Err(e) => Err(e)
                Ok(header) =>
                  match parse_claims(payload_json) {
                    Err(e) => Err(e)
                    Ok(claims) =>
                      Ok({
                        raw: token_string,
                        header,
                        payload: claims,
                        signature: signature_b64,
                      })
                  }
              }
          }
      }
  }
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

  // Convert bytes to string
  Ok(bytes.to_string())
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
    Some(json_val) =>
      match json_val {
        String(s) => s
        _ =>
          return Err(
            @oauth2.OAuth2Error::new_other("Invalid 'alg' in JWT header"),
          )
      }
    None =>
      return Err(@oauth2.OAuth2Error::new_other("Missing 'alg' in JWT header"))
  }

  let typ = match obj.get("typ") {
    Some(json_val) =>
      match json_val {
        String(s) => s
        _ => "JWT"
      }
    None => "JWT" // Default to "JWT" if not present
  }

  let kid = match obj.get("kid") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
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
    Some(json_val) =>
      match json_val {
        String(s) => s
        _ => return Err(@oauth2.OAuth2Error::new_other("Invalid 'iss' claim"))
      }
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'iss' claim"))
  }

  let sub = match obj.get("sub") {
    Some(json_val) =>
      match json_val {
        String(s) => s
        _ => return Err(@oauth2.OAuth2Error::new_other("Invalid 'sub' claim"))
      }
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'sub' claim"))
  }

  let aud = match obj.get("aud") {
    Some(json_val) =>
      match json_val {
        String(s) => s
        Array(arr) => {
          // Audience can be an array, take the first one
          if arr.length() == 0 {
            return Err(@oauth2.OAuth2Error::new_other("Empty 'aud' array"))
          }
          match arr[0] {
            String(s) => s
            _ =>
              return Err(
                @oauth2.OAuth2Error::new_other("Invalid 'aud' claim in array"),
              )
          }
        }
        _ => return Err(@oauth2.OAuth2Error::new_other("Invalid 'aud' claim"))
      }
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'aud' claim"))
  }

  let exp = match obj.get("exp") {
    Some(json_val) =>
      match json_val {
        Number(n, ..) => n.to_int64()
        _ => return Err(@oauth2.OAuth2Error::new_other("Invalid 'exp' claim"))
      }
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'exp' claim"))
  }

  let iat = match obj.get("iat") {
    Some(json_val) =>
      match json_val {
        Number(n, ..) => n.to_int64()
        _ => return Err(@oauth2.OAuth2Error::new_other("Invalid 'iat' claim"))
      }
    None => return Err(@oauth2.OAuth2Error::new_other("Missing 'iat' claim"))
  }

  // Optional claims
  let auth_time = match obj.get("auth_time") {
    Some(json_val) =>
      match json_val {
        Number(n, ..) => Some(n.to_int64())
        _ => None
      }
    None => None
  }

  let nonce = match obj.get("nonce") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
  }

  let name = match obj.get("name") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
  }

  let given_name = match obj.get("given_name") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
  }

  let family_name = match obj.get("family_name") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
  }

  let email = match obj.get("email") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
  }

  let email_verified = match obj.get("email_verified") {
    Some(json_val) =>
      match json_val {
        True => Some(true)
        False => Some(false)
        _ => None
      }
    None => None
  }

  let picture = match obj.get("picture") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
  }

  let locale = match obj.get("locale") {
    Some(json_val) =>
      match json_val {
        String(s) => Some(s)
        _ => None
      }
    None => None
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
