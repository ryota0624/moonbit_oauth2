///| UserInfo Endpoint Implementation

///|
/// UserInfo represents user information from the UserInfo Endpoint
pub struct UserInfo {
  sub : String // Required: User ID (must match ID Token's sub)
  name : String?
  given_name : String?
  family_name : String?
  email : String?
  email_verified : Bool?
  picture : String?
  profile : String?
  locale : String?
  updated_at : Int64?
} derive(Show)

///|
/// UserInfo Endpoint URL
pub struct UserInfoUrl {
  url : String
} derive(Show, Eq)

///|
/// Create a new UserInfoUrl
pub fn UserInfoUrl::new(url : String) -> UserInfoUrl {
  { url, }
}

///|
/// Get the string value of UserInfoUrl
pub fn UserInfoUrl::to_string(self : UserInfoUrl) -> String {
  self.url
}

///|
/// UserInfo Request
pub struct UserInfoRequest {
  userinfo_url : UserInfoUrl
  access_token : @oauth2.AccessToken
} derive(Show)

///|
/// Create a new UserInfoRequest
pub fn UserInfoRequest::new(
  userinfo_url : UserInfoUrl,
  access_token : @oauth2.AccessToken,
) -> UserInfoRequest {
  { userinfo_url, access_token }
}

///|
/// Execute the UserInfo request using HTTP client
/// Returns UserInfo on success, OAuth2Error on failure
pub async fn UserInfoRequest::execute(
  self : UserInfoRequest,
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[UserInfo, @oauth2.OAuth2Error] {
  // Set up headers with Bearer token
  let headers : @oauth2.HttpHeaders = {}
  headers["Authorization"] = "Bearer \{self.access_token.to_string()}"
  headers["Accept"] = "application/json"

  // Send GET request
  let response = match http_client.get(self.userinfo_url.to_string(), headers) {
    Ok(resp) => resp
    Err(err) => return Err(err)
  }

  // Check if response is successful (2xx status code)
  if response.is_error() {
    // Parse OAuth2 error from response body
    let error = @oauth2.parse_oauth2_error(response.body)
    return Err(error)
  }

  // Parse UserInfo response
  parse_userinfo(response.body)
}

///|
/// Parse UserInfo from JSON string
pub fn parse_userinfo(
  json_str : String,
) -> Result[UserInfo, @oauth2.OAuth2Error] {
  let json = @json.parse(json_str) catch {
    e =>
      return Err(
        @oauth2.OAuth2Error::new_other("Failed to parse UserInfo JSON: \{e}"),
      )
  }

  let obj = match json {
    Object(o) => o
    _ =>
      return Err(
        @oauth2.OAuth2Error::new_other("UserInfo must be a JSON object"),
      )
  }

  // Required field: sub
  let sub = match obj.get("sub") {
    Some(json_val) =>
      match json_val {
        String(s) => s
        _ =>
          return Err(
            @oauth2.OAuth2Error::new_other("Invalid 'sub' in UserInfo"),
          )
      }
    None =>
      return Err(@oauth2.OAuth2Error::new_other("Missing 'sub' in UserInfo"))
  }

  // Optional fields
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

  let profile = match obj.get("profile") {
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

  let updated_at = match obj.get("updated_at") {
    Some(json_val) =>
      match json_val {
        Number(n, ..) => Some(n.to_int64())
        _ => None
      }
    None => None
  }

  Ok({
    sub,
    name,
    given_name,
    family_name,
    email,
    email_verified,
    picture,
    profile,
    locale,
    updated_at,
  })
}

///|
/// Get the subject (user ID)
pub fn UserInfo::subject(self : UserInfo) -> String {
  self.sub
}

///|
/// Get the user's name if present
pub fn UserInfo::name(self : UserInfo) -> String? {
  self.name
}

///|
/// Get the user's given name if present
pub fn UserInfo::given_name(self : UserInfo) -> String? {
  self.given_name
}

///|
/// Get the user's family name if present
pub fn UserInfo::family_name(self : UserInfo) -> String? {
  self.family_name
}

///|
/// Get the user's email if present
pub fn UserInfo::email(self : UserInfo) -> String? {
  self.email
}

///|
/// Get the email verification status if present
pub fn UserInfo::email_verified(self : UserInfo) -> Bool? {
  self.email_verified
}

///|
/// Get the user's picture URL if present
pub fn UserInfo::picture(self : UserInfo) -> String? {
  self.picture
}

///|
/// Get the user's profile URL if present
pub fn UserInfo::profile(self : UserInfo) -> String? {
  self.profile
}

///|
/// Get the user's locale if present
pub fn UserInfo::locale(self : UserInfo) -> String? {
  self.locale
}

///|
/// Get the user's last update timestamp if present
pub fn UserInfo::updated_at(self : UserInfo) -> Int64? {
  self.updated_at
}
