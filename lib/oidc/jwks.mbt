///| JSON Web Key Set (JWKS) Implementation (RFC 7517)

///|
/// JsonWebKey represents a JSON Web Key (JWK)
/// See: https://datatracker.ietf.org/doc/html/rfc7517
pub struct JsonWebKey {
  // Standard JWK fields
  kty : String // Key Type (e.g., "RSA", "EC")
  use_ : String? // Public Key Use (e.g., "sig" for signature, "enc" for encryption)
  kid : String // Key ID - identifier for the key
  alg : String? // Algorithm (e.g., "RS256", "ES256")
  // RSA-specific fields (RFC 7518, Section 6.3)
  n : String? // RSA Modulus (Base64URL encoded)
  e : String? // RSA Exponent (Base64URL encoded)
  // EC-specific fields (not implemented yet)
  // crv : String?  // Curve (e.g., "P-256")
  // x : String?    // X coordinate
  // y : String?    // Y coordinate
} derive(Show, Eq)

///|
/// JsonWebKeySet represents a set of JSON Web Keys
/// See: https://datatracker.ietf.org/doc/html/rfc7517#section-5
pub struct JsonWebKeySet {
  keys : Array[JsonWebKey] // Array of JSON Web Keys
} derive(Show, Eq)

///|
/// JWKError represents errors that occur during JWK/JWKS parsing
pub enum JWKError {
  InvalidJson(String) // JSON parsing failed
  InvalidStructure(String) // Structure validation failed (e.g., not an object, missing required fields)
  InvalidFieldType(String) // Field has wrong type
  MissingRequiredField(String) // Required field is missing
  NoValidKeys // No valid JWKs found in JWKS
} derive(Show, Eq)

///|
/// Convert JWKError to string message
pub fn JWKError::message(self : JWKError) -> String {
  match self {
    InvalidJson(msg) => "Failed to parse JSON: \{msg}"
    InvalidStructure(msg) => "Invalid JWKS structure: \{msg}"
    InvalidFieldType(msg) => "Invalid field type: \{msg}"
    MissingRequiredField(msg) => "Missing required field: \{msg}"
    NoValidKeys => "No valid JWKs found in JWKS"
  }
}

///|
/// Fetch JWKS from the specified URI
///
/// Fetches the JSON Web Key Set from the JWKS endpoint.
///
/// # Arguments
/// * `jwks_uri` - The JWKS endpoint URL
/// * `http_client` - HTTP client for making requests
///
/// # Returns
/// * `Ok(JsonWebKeySet)` - Successfully fetched and parsed JWKS
/// * `Err(OAuth2Error)` - Failed to fetch or parse JWKS
///
/// # Example
/// ```moonbit nocheck
/// let http_client = @oauth2.OAuth2HttpClient::new()
/// let discovery = @oidc.fetch_google_discovery(http_client)?
/// let jwks = @oidc.fetch_jwks(discovery.jwks_uri, http_client)?
/// ```
pub async fn fetch_jwks(
  jwks_uri : String,
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[JsonWebKeySet, @oauth2.OAuth2Error] {
  // Set up headers
  let headers : @oauth2.HttpHeaders = {}
  headers["Accept"] = "application/json"
  headers["User-Agent"] = "moonbit-oauth2/0.1.2"

  // Send GET request
  let response = match http_client.get(jwks_uri, headers) {
    Ok(resp) => resp
    Err(err) =>
      return Err(
        @oauth2.OAuth2Error::new_other("Failed to fetch JWKS: \{err.message()}"),
      )
  }

  // Check if response is successful
  if response.is_error() {
    return Err(
      @oauth2.OAuth2Error::new_other(
        "JWKS request failed with status \{response.status_code}",
      ),
    )
  }

  // Parse JWKS and convert JWKError to OAuth2Error
  parse_jwks(response.body).map_err(fn(jwk_err) {
    @oauth2.OAuth2Error::new_other("JWKS parsing failed: \{jwk_err.message()}")
  })
}

///|
/// Parse JWKS from JSON string
///
/// # Arguments
/// * `json_str` - JSON string containing JWKS
///
/// # Returns
/// * `Ok(JsonWebKeySet)` - Successfully parsed JWKS
/// * `Err(JWKError)` - Failed to parse or invalid format
fn parse_jwks(json_str : String) -> Result[JsonWebKeySet, JWKError] {
  // Parse JSON
  let json = @json.parse(json_str) catch {
    e => return Err(InvalidJson(e.to_string()))
  }

  let obj = match json {
    Object(o) => o
    _ => return Err(InvalidStructure("JWKS must be a JSON object"))
  }

  // Extract keys array
  let keys_array = match obj.get("keys") {
    Some(Array(arr)) => arr
    Some(_) => return Err(InvalidFieldType("'keys' must be an array"))
    None => return Err(MissingRequiredField("'keys' field is missing in JWKS"))
  }

  // Parse each JWK
  let keys : Array[JsonWebKey] = []
  for i = 0; i < keys_array.length(); i = i + 1 {
    // Parse individual JWK (inlined to avoid type annotation issues)
    let parse_result = {
      let obj = match keys_array[i] {
        Object(o) => o
        _ => continue // Skip non-object JWKs
      }

      // Extract required fields
      let kty = match obj.get("kty") {
        Some(String(s)) => s
        Some(_) => continue // Skip invalid kty
        None => continue // Skip missing kty
      }

      let kid = match obj.get("kid") {
        Some(String(s)) => s
        Some(_) => continue // Skip invalid kid
        None => continue // Skip missing kid
      }

      // Extract optional fields
      let use_ = match obj.get("use") {
        Some(String(s)) => Some(s)
        _ => None
      }

      let alg = match obj.get("alg") {
        Some(String(s)) => Some(s)
        _ => None
      }

      // Extract RSA-specific fields
      let n = match obj.get("n") {
        Some(String(s)) => Some(s)
        _ => None
      }

      let e = match obj.get("e") {
        Some(String(s)) => Some(s)
        _ => None
      }

      // Validate RSA keys have required fields
      if kty == "RSA" {
        if n is None {
          continue // Skip RSA keys without modulus
        }
        if e is None {
          continue // Skip RSA keys without exponent
        }
      }

      // Successfully parsed JWK
      Some({ kty, use_, kid, alg, n, e })
    }

    match parse_result {
      Some(jwk) => keys.push(jwk)
      None => () // Already skipped via continue
    }
  }

  // Check if we got at least one valid key
  if keys.length() == 0 {
    return Err(NoValidKeys)
  }

  Ok({ keys, })
}

///|
/// Get all keys in the JWKS
pub fn JsonWebKeySet::get_all_keys(self : JsonWebKeySet) -> Array[JsonWebKey] {
  self.keys
}

///|
/// Find a JWK by its Key ID (kid)
///
/// # Arguments
/// * `kid` - The Key ID to search for
///
/// # Returns
/// * `Some(JsonWebKey)` - Found JWK with matching kid
/// * `None` - No JWK with matching kid found
pub fn JsonWebKeySet::find_by_kid(
  self : JsonWebKeySet,
  kid : String,
) -> JsonWebKey? {
  for i = 0; i < self.keys.length(); i = i + 1 {
    let key = self.keys[i]
    if key.kid == kid {
      return Some(key)
    }
  }
  None
}

///|
/// Find an RSA JWK by its Key ID (kid)
///
/// This is a convenience method that filters for RSA keys specifically.
///
/// # Arguments
/// * `kid` - The Key ID to search for
///
/// # Returns
/// * `Some(JsonWebKey)` - Found RSA JWK with matching kid
/// * `None` - No RSA JWK with matching kid found
pub fn JsonWebKeySet::find_rsa_key_by_kid(
  self : JsonWebKeySet,
  kid : String,
) -> JsonWebKey? {
  for i = 0; i < self.keys.length(); i = i + 1 {
    let key = self.keys[i]
    if key.kid == kid && key.kty == "RSA" {
      return Some(key)
    }
  }
  None
}

///|
/// Get the Key Type (kty)
pub fn JsonWebKey::kty(self : JsonWebKey) -> String {
  self.kty
}

///|
/// Get the Key ID (kid)
pub fn JsonWebKey::kid(self : JsonWebKey) -> String {
  self.kid
}

///|
/// Get the Public Key Use (use)
pub fn JsonWebKey::use_(self : JsonWebKey) -> String? {
  self.use_
}

///|
/// Get the Algorithm (alg)
pub fn JsonWebKey::alg(self : JsonWebKey) -> String? {
  self.alg
}

///|
/// Get the RSA Modulus (n) if this is an RSA key
pub fn JsonWebKey::rsa_modulus(self : JsonWebKey) -> String? {
  self.n
}

///|
/// Get the RSA Exponent (e) if this is an RSA key
pub fn JsonWebKey::rsa_exponent(self : JsonWebKey) -> String? {
  self.e
}

///|
/// Check if this is an RSA key
pub fn JsonWebKey::is_rsa(self : JsonWebKey) -> Bool {
  self.kty == "RSA"
}

///|
/// Check if this is an EC (Elliptic Curve) key
pub fn JsonWebKey::is_ec(self : JsonWebKey) -> Bool {
  self.kty == "EC"
}
