///| Basic OAuth2 Type Definitions

///|
/// ClientId represents the OAuth2 client identifier
struct ClientId {
  value : String
} derive(Show, Eq)

///|
/// Create a new ClientId
pub fn ClientId::new(value : String) -> ClientId {
  { value, }
}

///|
/// Get the string value of ClientId
pub fn ClientId::to_string(self : ClientId) -> String {
  self.value
}

///| Client Secret

///|
/// ClientSecret represents the OAuth2 client secret
struct ClientSecret {
  value : String
} derive(Show, Eq)

///|
/// Create a new ClientSecret
pub fn ClientSecret::new(value : String) -> ClientSecret {
  { value, }
}

///|
/// Get the string value of ClientSecret
pub fn ClientSecret::to_string(self : ClientSecret) -> String {
  self.value
}

///| URLs

///|
/// AuthUrl represents the authorization endpoint URL
struct AuthUrl {
  value : String
} derive(Show, Eq)

///|
/// Create a new AuthUrl
pub fn AuthUrl::new(value : String) -> AuthUrl {
  { value, }
}

///|
/// Get the string value of AuthUrl
pub fn AuthUrl::to_string(self : AuthUrl) -> String {
  self.value
}

///|
/// TokenUrl represents the token endpoint URL
struct TokenUrl {
  value : String
} derive(Show, Eq)

///|
/// Create a new TokenUrl
pub fn TokenUrl::new(value : String) -> TokenUrl {
  { value, }
}

///|
/// Get the string value of TokenUrl
pub fn TokenUrl::to_string(self : TokenUrl) -> String {
  self.value
}

///|
/// RedirectUrl represents the redirect URL for OAuth2 callback
struct RedirectUrl {
  value : String
} derive(Show, Eq)

///|
/// Create a new RedirectUrl
pub fn RedirectUrl::new(value : String) -> RedirectUrl {
  { value, }
}

///|
/// Get the string value of RedirectUrl
pub fn RedirectUrl::to_string(self : RedirectUrl) -> String {
  self.value
}

///| Scope

///|
/// Scope represents OAuth2 access scope
struct Scope {
  value : String
} derive(Show, Eq)

///|
/// Create a new Scope
pub fn Scope::new(value : String) -> Scope {
  { value, }
}

///|
/// Get the string value of Scope
pub fn Scope::to_string(self : Scope) -> String {
  self.value
}

///|
/// OIDC standard scope: openid (required for OIDC)
pub fn Scope::openid() -> Scope {
  Scope::new("openid")
}

///|
/// OIDC standard scope: profile
pub fn Scope::profile() -> Scope {
  Scope::new("profile")
}

///|
/// OIDC standard scope: email
pub fn Scope::email() -> Scope {
  Scope::new("email")
}

///|
/// OIDC standard scope: address
pub fn Scope::address() -> Scope {
  Scope::new("address")
}

///|
/// OIDC standard scope: phone
pub fn Scope::phone() -> Scope {
  Scope::new("phone")
}

///| Tokens

///|
/// AccessToken represents the OAuth2 access token
struct AccessToken {
  value : String
} derive(Show, Eq)

///|
/// Create a new AccessToken
pub fn AccessToken::new(value : String) -> AccessToken {
  { value, }
}

///|
/// Get the string value of AccessToken
pub fn AccessToken::to_string(self : AccessToken) -> String {
  self.value
}

///|
/// RefreshToken represents the OAuth2 refresh token
struct RefreshToken {
  value : String
} derive(Show, Eq)

///|
/// Create a new RefreshToken
pub fn RefreshToken::new(value : String) -> RefreshToken {
  { value, }
}

///|
/// Get the string value of RefreshToken
pub fn RefreshToken::to_string(self : RefreshToken) -> String {
  self.value
}

///| CSRF Protection

///|
/// CsrfToken represents the state parameter for CSRF protection
struct CsrfToken {
  value : String
} derive(Show, Eq)

///|
/// Create a new CsrfToken
pub fn CsrfToken::new(value : String) -> CsrfToken {
  { value, }
}

///|
/// Get the string value of CsrfToken
pub fn CsrfToken::to_string(self : CsrfToken) -> String {
  self.value
}

///| Nonce (OIDC)

///|
/// Nonce represents the nonce parameter for OIDC replay attack protection
struct Nonce {
  value : String
} derive(Show, Eq)

///|
/// Create a new Nonce
pub fn Nonce::new(value : String) -> Nonce {
  { value, }
}

///|
/// Get the string value of Nonce
pub fn Nonce::to_string(self : Nonce) -> String {
  self.value
}

///| Token Response

///|
/// TokenResponse represents the response from the token endpoint
pub struct TokenResponse {
  access_token : AccessToken
  token_type : String
  expires_in : Int?
  refresh_token : RefreshToken?
  scope : String?
  id_token : String? // OIDC: ID Token (JWT string)
} derive(Show)

///|
/// Create a new TokenResponse
pub fn TokenResponse::new(
  access_token : AccessToken,
  token_type : String,
  expires_in : Int?,
  refresh_token : RefreshToken?,
  scope : String?,
  id_token : String?,
) -> TokenResponse {
  { access_token, token_type, expires_in, refresh_token, scope, id_token }
}

///|
/// Get the access token
pub fn TokenResponse::access_token(self : TokenResponse) -> AccessToken {
  self.access_token
}

///|
/// Get the token type
pub fn TokenResponse::token_type(self : TokenResponse) -> String {
  self.token_type
}

///|
/// Get the expiration time in seconds
pub fn TokenResponse::expires_in(self : TokenResponse) -> Int? {
  self.expires_in
}

///|
/// Get the refresh token if present
pub fn TokenResponse::refresh_token(self : TokenResponse) -> RefreshToken? {
  self.refresh_token
}

///|
/// Get the scope if present
pub fn TokenResponse::scope(self : TokenResponse) -> String? {
  self.scope
}

///|
/// Get the ID Token if present (OIDC)
pub fn TokenResponse::id_token(self : TokenResponse) -> String? {
  self.id_token
}
