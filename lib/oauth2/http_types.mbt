///| HTTP Request and Response Types

///|
/// HttpMethod represents HTTP request methods
pub enum HttpMethod {
  GET
  POST
  PUT
  DELETE
} derive(Show, Eq)

///|
/// Convert HttpMethod to string
pub fn HttpMethod::to_string(self : HttpMethod) -> String {
  match self {
    GET => "GET"
    POST => "POST"
    PUT => "PUT"
    DELETE => "DELETE"
  }
}

///|
/// HttpHeaders represents HTTP headers as a map
pub type HttpHeaders = Map[String, String]

///|
/// HttpRequest represents an HTTP request
pub struct HttpRequest {
  url : String
  http_method : HttpMethod
  headers : HttpHeaders
  body : String
} derive(Show)

///|
/// Create a new HttpRequest
pub fn HttpRequest::new(
  url : String,
  http_method : HttpMethod,
  headers : HttpHeaders,
  body : String,
) -> HttpRequest {
  { url, http_method, headers, body }
}

///|
/// HttpResponse represents an HTTP response
pub struct HttpResponse {
  status_code : Int
  headers : HttpHeaders
  body : String
} derive(Show)

///|
/// Create a new HttpResponse
pub fn HttpResponse::new(
  status_code : Int,
  headers : HttpHeaders,
  body : String,
) -> HttpResponse {
  { status_code, headers, body }
}

///|
/// Check if response is successful (2xx status code)
pub fn HttpResponse::is_success(self : HttpResponse) -> Bool {
  self.status_code >= 200 && self.status_code < 300
}

///|
/// Check if response is error (4xx or 5xx status code)
pub fn HttpResponse::is_error(self : HttpResponse) -> Bool {
  self.status_code >= 400
}
