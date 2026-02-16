///| HTTP Client Implementation using mizchi/x

///|
/// OAuth2HttpClient provides HTTP functionality for OAuth2 operations
pub struct OAuth2HttpClient {
  debug : Bool // Debug output flag (default: false)
}

///|
/// Create a new OAuth2HttpClient with debug output disabled (default)
pub fn OAuth2HttpClient::new() -> OAuth2HttpClient {
  { debug: false }
}

///|
/// Create a new OAuth2HttpClient with configurable debug output
pub fn OAuth2HttpClient::new_with_debug(debug : Bool) -> OAuth2HttpClient {
  { debug, }
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
/// Base64 encode a string using moonbitlang/x/codec/base64
/// Standard encoding with padding
fn base64_encode(s : String) -> String {
  // Convert String to BytesView for library
  let bytes = string_to_bytes_view(s)
  @base64.encode(bytes, url_safe=false)
}

///|
/// Base64URL encode a string (RFC 4648 Section 5)
/// Uses URL-safe alphabet: replaces + with - and / with _
/// Removes padding (=) characters
pub fn base64url_encode(s : String) -> String {
  // Convert String to BytesView for library
  let bytes = string_to_bytes_view(s)
  // Encode with URL-safe alphabet and padding
  let encoded = @base64.encode(bytes, url_safe=true)
  // Remove padding characters for RFC 4648 Section 5 compliance
  let mut end = encoded.length()
  while end > 0 && encoded[end - 1] == '=' {
    end = end - 1
  }
  // Build result without padding
  let result = StringBuilder::new()
  for i = 0; i < end; i = i + 1 {
    result.write_char(encoded[i].unsafe_to_char())
  }
  result.to_string()
}

///|
/// Convert String to BytesView for base64 encoding
fn string_to_bytes_view(s : String) -> BytesView {
  let fixed_array = FixedArray::make(s.length(), Byte::default())
  for i = 0; i < s.length(); i = i + 1 {
    fixed_array[i] = s[i].to_int().to_byte()
  }
  let bytes = Bytes::from_array(fixed_array[:])
  bytes.op_as_view()
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
/// Extract string value from JSON using @json package
fn extract_json_string_value(json : String, key : String) -> String? {
  let parsed = @json.parse(json) catch { _ => return None }

  match parsed {
    Object(map) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Send HTTP POST request using mizchi/x
pub async fn OAuth2HttpClient::post(
  self : OAuth2HttpClient,
  url : String,
  headers : HttpHeaders,
  body : String,
) -> Result[HttpResponse, OAuth2Error] {
  // Convert headers to mizchi/x format
  let http_headers = convert_headers(headers)

  // Debug: print request details
  if self.debug {
    println("DEBUG http_client POST:")
    println("  URL: \{url}")
    println("  Body length: \{body.length()}")
  }

  // Send POST request using mizchi/x
  let (response, response_body) = @http.post(url, body, headers=http_headers) catch {
    err => return Err(HttpError("HTTP request failed: \{err}"))
  }

  if self.debug {
    println("DEBUG after @http.post:")
    println("  Response code: \{response.code}")
  }

  // Convert response to our HttpResponse type
  let response_headers : HttpHeaders = {}
  response.headers.each(fn(key, value) { response_headers[key] = value })

  // Read body text
  let body_text = response_body.text()

  // Debug: print response details
  if self.debug {
    println("DEBUG http_client response:")
    println("  Status: \{response.code}")
    println("  Body length: \{body_text.length()}")
    if body_text.length() > 0 {
      let preview_len = if body_text.length() < 100 {
        body_text.length()
      } else {
        100
      }
      println(
        "  Body (first 100 chars): \{body_text[0:preview_len].to_string()}",
      )
    }
  }

  Ok(HttpResponse::new(response.code, response_headers, body_text))
}

///|
/// Send HTTP GET request
/// Used for OIDC UserInfo Endpoint and other GET requests
pub async fn OAuth2HttpClient::get(
  self : OAuth2HttpClient,
  url : String,
  headers : HttpHeaders,
) -> Result[HttpResponse, OAuth2Error] {
  // Convert headers to mizchi/x format
  let http_headers = convert_headers(headers)

  // Debug: print request details
  if self.debug {
    println("DEBUG http_client GET:")
    println("  URL: \{url}")
  }

  // Send GET request using mizchi/x
  let (response, response_body) = @http.get(url, headers=http_headers) catch {
    err => return Err(HttpError("HTTP request failed: \{err}"))
  }

  if self.debug {
    println("DEBUG after @http.get:")
    println("  Response code: \{response.code}")
  }

  // Convert response to our HttpResponse type
  let response_headers : HttpHeaders = {}
  response.headers.each(fn(key, value) { response_headers[key] = value })

  // Read body text
  let body_text = response_body.text()

  // Debug: print response details
  if self.debug {
    println("DEBUG http_client response:")
    println("  Status: \{response.code}")
    println("  Body length: \{body_text.length()}")
    if body_text.length() > 0 {
      let preview_len = if body_text.length() < 100 {
        body_text.length()
      } else {
        100
      }
      println(
        "  Body (first 100 chars): \{body_text[0:preview_len].to_string()}",
      )
    }
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
