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
/// Simple URL encoding for form data
/// TODO: Implement proper URL encoding
fn url_encode(s : String) -> String {
  // For now, just return the string as-is
  // In production, this should properly encode special characters
  s
}

///|
/// Build Basic Authentication header value
pub fn build_basic_auth_header(
  client_id : ClientId,
  client_secret : ClientSecret,
) -> String {
  let credentials = "\{client_id.to_string()}:\{client_secret.to_string()}"
  // TODO: Implement proper Base64 encoding
  // For now, return the raw credentials
  "Basic \{credentials}"
}

///|
/// Parse OAuth2 error from response body
pub fn parse_oauth2_error(body : String) -> OAuth2Error {
  // TODO: Implement proper JSON parsing
  // For now, return a generic error
  ParseError("Failed to parse error response: \{body}")
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

  // Send POST request using mizchi/x
  let (response, response_body) = @http.post(url, body, headers=http_headers) catch {
    err => return Err(HttpError("HTTP request failed: \{err}"))
  }

  // Convert response to our HttpResponse type
  let response_headers : HttpHeaders = {}
  response.headers.each(fn(key, value) { response_headers[key] = value })

  let body_text = response_body.text()

  Ok(HttpResponse::new(response.code, response_headers, body_text))
}
