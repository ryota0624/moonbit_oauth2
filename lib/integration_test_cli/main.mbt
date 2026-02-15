///| Integration Test CLI Tool
///
/// This tool performs actual HTTP communication tests with mock-oauth2-server
/// Run: moon run lib/integration_test_cli

async fn main {
  println("🧪 OAuth2 Integration Test Tool")
  println("==================================================")
  test_client_credentials()
}

///|
/// Test Client Credentials Grant with actual HTTP communication
async fn test_client_credentials() -> Unit {
  println("\n📋 Test 1: Client Credentials Grant")
  println("--------------------------------------------------")

  let token_url = @oauth2.TokenUrl::new("http://localhost:8081/default/token")
  let client_id = @oauth2.ClientId::new("test_client")
  let client_secret = @oauth2.ClientSecret::new("test_secret")
  let scopes = [
    @oauth2.Scope::new("api:read"),
    @oauth2.Scope::new("api:write"),
  ]

  let request = @oauth2.ClientCredentialsRequest::new(
    token_url, client_id, client_secret, scopes,
  )

  println("  Token URL: \{token_url.to_string()}")
  println("  Client ID: \{client_id.to_string()}")
  println("  Scopes: api:read, api:write")

  println("\n  Sending request...")

  let http_client = @oauth2.OAuth2HttpClient::new()
  let result = request.execute(http_client)

  match result {
    Ok(token_response) => {
      println("  ✅ Success! Token received:")
      let token_str = token_response.access_token().to_string()
      let preview = if token_str.length() > 20 {
        token_str[0:20].to_string() + "..."
      } else {
        token_str
      }
      println("    - Access Token: \{preview}")
      println("    - Token Type: \{token_response.token_type()}")
      match token_response.expires_in() {
        Some(expires) => println("    - Expires In: \{expires} seconds")
        None => println("    - Expires In: Not specified")
      }
      match token_response.scope() {
        Some(scope) => println("    - Scope: \{scope}")
        None => println("    - Scope: Not specified")
      }
    }
    Err(error) => {
      println("  ❌ Error: \{error.message()}")
    }
  }
}
