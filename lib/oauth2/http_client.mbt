///| HTTP Client Implementation using mizchi/x

///|
/// OAuth2HttpClient provides HTTP functionality for OAuth2 operations
pub struct OAuth2HttpClient {
  // Placeholder for future client configuration
  _dummy : Unit
}

///|
/// Create a new OAuth2HttpClient
pub fn OAuth2HttpClient::new() -> OAuth2HttpClient {
  { _dummy: () }
}

///|
/// Convert HttpHeaders to mizchi/x format
fn convert_headers(headers : HttpHeaders) -> Map[String, String] {
  let result : Map[String, String] = {}
  headers.each(fn(key, value) { result[key] = value })
  result
}

///|
/// Build application/x-www-form-urlencoded body from parameters
pub fn build_form_urlencoded_body(params : Map[String, String]) -> String {
  let parts : Array[String] = []
  params.each(fn(key, value) {
    let encoded_key = url_encode(key)
    let encoded_value = url_encode(value)
    parts.push("\{encoded_key}=\{encoded_value}")
  })
  parts.join("&")
}

///|
/// URL encoding for form data (RFC 3986)
/// Encodes special characters as %XX where XX is the hex value
pub fn url_encode(s : String) -> String {
  let result = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    let code = ch.to_int()
    // Unreserved characters: A-Z, a-z, 0-9, -, _, ., ~
    if (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      code == 45 ||
      code == 95 ||
      code == 46 ||
      code == 126 {
      result.write_char(ch.unsafe_to_char())
    } else {
      // Encode as %XX
      result.write_string("%")
      result.write_string(int_to_hex(code))
    }
  }
  result.to_string()
}

///|
/// Convert integer to 2-digit uppercase hex string
pub fn int_to_hex(n : Int) -> String {
  let hex_chars = "0123456789ABCDEF"
  let high = n / 16 % 16
  let low = n % 16
  let result = StringBuilder::new()
  result.write_char(hex_chars[high].unsafe_to_char())
  result.write_char(hex_chars[low].unsafe_to_char())
  result.to_string()
}

///|
/// Build Basic Authentication header value
pub fn build_basic_auth_header(
  client_id : ClientId,
  client_secret : ClientSecret,
) -> String {
  let credentials = "\{client_id.to_string()}:\{client_secret.to_string()}"
  let encoded = base64_encode(credentials)
  "Basic \{encoded}"
}

///|
/// Base64 encode a string
fn base64_encode(s : String) -> String {
  base64_encode_internal(s, false, true)
}

///|
/// Base64URL encode a string (RFC 4648 Section 5)
/// Uses URL-safe alphabet: replaces + with - and / with _
/// Removes padding (=) characters
pub fn base64url_encode(s : String) -> String {
  base64_encode_internal(s, true, false)
}

///|
/// Internal Base64 encoding with options for standard vs URL-safe encoding
fn base64_encode_internal(
  s : String,
  use_url_safe : Bool,
  add_padding : Bool,
) -> String {
  let base64_chars = if use_url_safe {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  } else {
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  }
  let result = StringBuilder::new()
  let mut i = 0
  while i < s.length() {
    let b1 = s[i].to_int()
    let b2 = if i + 1 < s.length() { s[i + 1].to_int() } else { 0 }
    let b3 = if i + 2 < s.length() { s[i + 2].to_int() } else { 0 }

    // Convert 3 bytes to 4 base64 characters
    let c1 = b1 >> 2
    let c2 = ((b1 & 0x03) << 4) | (b2 >> 4)
    let c3 = ((b2 & 0x0F) << 2) | (b3 >> 6)
    let c4 = b3 & 0x3F

    result.write_char(base64_chars[c1].unsafe_to_char())
    result.write_char(base64_chars[c2].unsafe_to_char())

    if i + 1 < s.length() {
      result.write_char(base64_chars[c3].unsafe_to_char())
    } else if add_padding {
      result.write_char('=')
    }

    if i + 2 < s.length() {
      result.write_char(base64_chars[c4].unsafe_to_char())
    } else if add_padding {
      result.write_char('=')
    }

    i = i + 3
  }
  result.to_string()
}

///|
/// Parse OAuth2 error from response body
/// Expects JSON format: {"error": "...", "error_description": "..."}
pub fn parse_oauth2_error(body : String) -> OAuth2Error {
  // Simple JSON parsing for OAuth2 error response
  let error_code = extract_json_string_value(body, "error")
  let error_description = extract_json_string_value(body, "error_description")

  match error_code {
    Some(code) => OAuth2Error::from_error_code(code, error_description)
    None => ParseError("Failed to parse error response: \{body}")
  }
}

///|
/// Extract string value from JSON-like text
/// Simple implementation for OAuth2 error responses
fn extract_json_string_value(json : String, key : String) -> String? {
  // Look for "key":"value" or "key": "value"
  let search_pattern = "\"\{key}\""
  let mut start_index = -1

  // Find the key
  for i = 0; i < json.length() - key.length() - 2; i = i + 1 {
    let mut matches = true
    for j = 0; j < search_pattern.length(); j = j + 1 {
      if json[i + j].to_int() != search_pattern[j].to_int() {
        matches = false
        break
      }
    }
    if matches {
      start_index = i + search_pattern.length()
      break
    }
  }

  if start_index == -1 {
    return None
  }

  // Skip whitespace and colon
  while start_index < json.length() &&
        (json[start_index].to_int() == 32 || json[start_index].to_int() == 58) {
    start_index = start_index + 1
  }

  // Skip whitespace after colon
  while start_index < json.length() && json[start_index].to_int() == 32 {
    start_index = start_index + 1
  }

  // Expect opening quote
  if start_index >= json.length() || json[start_index].to_int() != 34 {
    return None
  }
  start_index = start_index + 1

  // Find closing quote
  let mut end_index = start_index
  while end_index < json.length() && json[end_index].to_int() != 34 {
    end_index = end_index + 1
  }

  if end_index >= json.length() {
    return None
  }

  // Extract the value
  let value = json[start_index:end_index].to_string() catch { _ => return None }
  Some(value)
}

///|
/// Send HTTP POST request using mizchi/x
pub async fn OAuth2HttpClient::post(
  _self : OAuth2HttpClient,
  url : String,
  headers : HttpHeaders,
  body : String,
) -> Result[HttpResponse, OAuth2Error] {
  // Convert headers to mizchi/x format
  let http_headers = convert_headers(headers)

  // Debug: print request details
  println("DEBUG http_client POST:")
  println("  URL: \{url}")
  println("  Body length: \{body.length()}")

  // Send POST request using mizchi/x
  let (response, response_body) = @http.post(url, body, headers=http_headers) catch {
    err => return Err(HttpError("HTTP request failed: \{err}"))
  }

  println("DEBUG after @http.post:")
  println("  Response code: \{response.code}")

  // Convert response to our HttpResponse type
  let response_headers : HttpHeaders = {}
  response.headers.each(fn(key, value) { response_headers[key] = value })

  // Read body text
  let body_text = response_body.text()

  // Debug: print response details
  println("DEBUG http_client response:")
  println("  Status: \{response.code}")
  println("  Body length: \{body_text.length()}")
  if body_text.length() > 0 {
    let preview_len = if body_text.length() < 100 { body_text.length() } else { 100 }
    println("  Body (first 100 chars): \{body_text[0:preview_len].to_string()}")
  }

  Ok(HttpResponse::new(response.code, response_headers, body_text))
}

///|
/// Build scope string from array of Scope
/// Joins scope values with space separator
pub fn build_scope_string(scopes : Array[Scope]) -> String {
  let scope_strs : Array[String] = []
  for i = 0; i < scopes.length(); i = i + 1 {
    scope_strs.push(scopes[i].to_string())
  }
  scope_strs.join(" ")
}
