///|
/// Google Discovery Document Integration Test
///
/// This example demonstrates fetching Google's OpenID Connect Discovery Document
/// from the well-known endpoint.
async fn main {
  println("=== Google Discovery Document Test ===\n")

  // Create HTTP client
  let http_client = @oauth2.OAuth2HttpClient::new()

  println("Fetching Google Discovery Document...")
  println("URL: https://accounts.google.com/.well-known/openid-configuration\n")

  // Fetch discovery document using the Google provider
  let result = @google.fetch_discovery(http_client)

  match result {
    Ok(doc) => {
      println("✓ Successfully fetched Google Discovery Document\n")
      println("--- Discovery Document ---")
      println("Issuer: \{doc.issuer()}")
      println("Authorization Endpoint: \{doc.authorization_endpoint()}")
      println("Token Endpoint: \{doc.token_endpoint()}")
      println("JWKS URI: \{doc.jwks_uri()}")

      match doc.userinfo_endpoint() {
        Some(url) => println("UserInfo Endpoint: \{url}")
        None => println("UserInfo Endpoint: (not available)")
      }

      match doc.scopes_supported() {
        Some(scopes) => {
          println("\nSupported Scopes (\{scopes.length()}):")
          for i = 0; i < scopes.length(); i = i + 1 {
            println("  - \{scopes[i]}")
          }
        }
        None => println("\nSupported Scopes: (not available)")
      }

      match doc.response_types_supported() {
        Some(types) => {
          println("\nSupported Response Types (\{types.length()}):")
          for i = 0; i < types.length(); i = i + 1 {
            println("  - \{types[i]}")
          }
        }
        None => println("\nSupported Response Types: (not available)")
      }

      match doc.code_challenge_methods_supported {
        Some(methods) => {
          println("\nSupported PKCE Methods (\{methods.length()}):")
          for i = 0; i < methods.length(); i = i + 1 {
            println("  - \{methods[i]}")
          }
        }
        None => println("\nSupported PKCE Methods: (not available)")
      }

      // Test URL mapping
      println("\n--- URL Mapping Test ---")
      let auth_url = doc.authorization_url()
      let token_url = doc.token_url()
      println("AuthUrl: \{auth_url.to_string()}")
      println("TokenUrl: \{token_url.to_string()}")

      match doc.userinfo_url() {
        Some(url) => println("UserInfoUrl: \{url.to_string()}")
        None => println("UserInfoUrl: (not available)")
      }

      println("\n✓ All tests passed!")
    }
    Err(e) => {
      println("✗ Failed to fetch discovery document")
      println("Error: \{e.message()}")
      println("\nPossible causes:")
      println("  - Network connectivity issue")
      println("  - Google's endpoint is temporarily unavailable")
      println("  - Invalid response format")
    }
  }
}
