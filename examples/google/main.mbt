///|
/// Google OAuth2 Authorization Code Flow with PKCE - Executable Sample
///
/// This example demonstrates the complete OAuth2 authorization flow with Google.
///
/// Setup:
/// 1. Copy .env.example to .env and fill in your credentials
/// 2. Set environment variables:
///    - GOOGLE_CLIENT_ID: Your Google OAuth2 Client ID
///    - GOOGLE_CLIENT_SECRET: Your Google OAuth2 Client Secret
///    - GOOGLE_REDIRECT_URI: Your redirect URI (e.g., http://localhost:3000/callback)
/// 3. Run the program and follow the authorization URL
/// 4. After authorization, provide the authorization code when prompted

///|
/// Environment configuration
struct Config {
  client_id : String
  client_secret : String
  redirect_uri : String
}

///|
/// Load configuration from environment variables
fn Config::from_env() -> Result[Config, String] {
  guard @sys.get_env_var("GOOGLE_CLIENT_ID") is Some(client_id) else {
    return Err(
      "GOOGLE_CLIENT_ID is not set. Please set it in your environment.",
    )
  }

  guard @sys.get_env_var("GOOGLE_CLIENT_SECRET") is Some(client_secret) else {
    return Err(
      "GOOGLE_CLIENT_SECRET is not set. Please set it in your environment.",
    )
  }

  let redirect_uri = @sys.get_env_var("GOOGLE_REDIRECT_URI").unwrap_or(
    "http://localhost:3000/callback",
  )

  Ok(Config::{ client_id, client_secret, redirect_uri })
}

///|
/// Print separator line
fn print_separator(title : String) -> Unit {
  println("")
  println("=".repeat(60))
  println(title)
  println("=".repeat(60))
  println("")
}

///|
/// Main entry point
async fn main {
  println("🔐 Google OAuth2 Authorization Code Flow with PKCE")
  println("")

  // Load configuration
  let config = match Config::from_env() {
    Ok(cfg) => cfg
    Err(err) => {
      println("❌ Configuration Error:")
      println("   \{err}")
      println("")
      println("💡 Setup Instructions:")
      println(
        "   1. Go to Google Cloud Console: https://console.cloud.google.com/",
      )
      println("   2. Create OAuth2 credentials")
      println("   3. Set environment variables:")
      println("      export GOOGLE_CLIENT_ID='your-client-id'")
      println("      export GOOGLE_CLIENT_SECRET='your-client-secret'")
      println(
        "      export GOOGLE_REDIRECT_URI='http://localhost:3000/callback'",
      )
      println("")
      return
    }
  }

  println("📋 Configuration:")
  println("   Client ID: \{config.client_id}")
  let secret_preview = if config.client_secret.length() > 10 {
    config.client_secret[0:10].to_string() + "..."
  } else {
    "***"
  }
  println("   Client Secret: \{secret_preview}")
  println("   Redirect URI: \{config.redirect_uri}")

  // Create HTTP client
  let http_client = @oauth2.OAuth2HttpClient::new()

  // Step 1: Fetch Google Discovery Document
  print_separator("Step 1: Fetch Discovery Document")
  println("Fetching Google OpenID Connect Discovery Document...")
  let discovery = match @google.fetch_discovery(http_client) {
    Ok(doc) => {
      println("✅ Discovery document fetched successfully")
      println("   Issuer: \{doc.issuer()}")
      println("   Authorization URL: \{doc.authorization_endpoint()}")
      println("   Token URL: \{doc.token_endpoint()}")
      doc
    }
    Err(e) => {
      println("❌ Failed to fetch discovery document")
      println("   Error: \{e.message()}")
      return
    }
  }

  // Step 2: Generate authorization URL with PKCE
  print_separator("Step 2: Generate Authorization URL")

  let state = @oauth2.generate_csrf_token()
  let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
  let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(
    pkce_verifier,
  )

  let scopes = [
    @oauth2.Scope::new("openid"),
    @oauth2.Scope::new("email"),
    @oauth2.Scope::new("profile"),
  ]

  let auth_request = @oauth2.AuthorizationRequest::new_with_pkce(
    discovery.authorization_url(),
    @oauth2.ClientId::new(config.client_id),
    @oauth2.RedirectUrl::new(config.redirect_uri),
    scopes,
    state,
    pkce_challenge,
  )

  let auth_url = auth_request.build_authorization_url()
  println("✅ Authorization URL generated")
  println("")
  println("🌐 Visit this URL to authorize:")
  println("\{auth_url}")
  println("")
  println("📝 Instructions:")
  println("   1. Open the URL above in your browser")
  println("   2. Sign in with your Google account")
  println("   3. Authorize the application")
  println("   4. You will be redirected to: \{config.redirect_uri}")
  println("   5. Copy the 'code' parameter from the redirect URL")

  // Step 3: Exchange authorization code for tokens
  print_separator("Step 3: Exchange Code for Tokens")

  println("📥 Please provide the authorization code:")
  println("   Set the AUTHORIZATION_CODE environment variable and re-run,")
  println("   or pass the code when prompted.")
  println("")

  // Get authorization code from environment variable
  guard @sys.get_env_var("AUTHORIZATION_CODE") is Some(authorization_code)
  else {
    println("❌ AUTHORIZATION_CODE environment variable is not set")
    println("")
    println("💡 Set it and re-run:")
    println("   export AUTHORIZATION_CODE='your-authorization-code'")
    println("   moon run -p examples/google")
    println("")
    return
  }
  println("✅ Authorization code received from environment")

  let token_request = @oauth2.TokenRequest::new_with_pkce(
    discovery.token_url(),
    @oauth2.ClientId::new(config.client_id),
    @oauth2.ClientSecret::new(config.client_secret),
    authorization_code,
    @oauth2.RedirectUrl::new(config.redirect_uri),
    pkce_verifier,
  )

  let token_response = match token_request.execute(http_client) {
    Ok(response) => {
      println("✅ Tokens received successfully")
      response
    }
    Err(e) => {
      println("❌ Failed to exchange authorization code for tokens")
      println("   Error: \{e.message()}")
      println("")
      println("💡 Common issues:")
      println("   - Authorization code has already been used")
      println("   - Authorization code has expired")
      println("   - Redirect URI mismatch")
      println("   - Invalid client credentials")
      println("")
      return
    }
  }

  // Step 4: Verify ID Token
  print_separator("Step 4: Verify ID Token")

  let id_token = match @oidc.get_id_token_from_response(token_response) {
    Ok(token) => {
      println("✅ ID Token extracted from response")
      token
    }
    Err(e) => {
      println("❌ Failed to extract ID Token")
      println("   Error: \{e.message()}")
      return
    }
  }

  match @google.verify_id_token(id_token, config.client_id, http_client, None) {
    Ok(_) => println("✅ ID Token verified successfully")
    Err(e) => {
      println("❌ ID Token verification failed")
      println("   Error: \{e.message()}")
      println("")
      println(
        "⚠️  Note: Signature verification is not yet fully implemented.",
      )
      println("   See lib/oidc/README.md for details.")
      // Continue anyway for demonstration purposes
    }
  }

  // Step 5: Display user information
  print_separator("Step 5: User Information")

  println("👤 User Information from ID Token:")
  println("   User ID (sub): \{id_token.subject()}")

  match id_token.email() {
    Some(email) => println("   Email: \{email}")
    None => println("   Email: N/A")
  }

  match id_token.name() {
    Some(name) => println("   Name: \{name}")
    None => println("   Name: N/A")
  }

  // Bonus: Display token information
  println("")
  println("🔑 Token Information:")
  println("   Token Type: \{token_response.token_type()}")

  match token_response.expires_in() {
    Some(expires) => println("   Expires In: \{expires} seconds")
    None => println("   Expires In: N/A")
  }

  let access_token_preview = {
    let token_str = token_response.access_token().to_string()
    if token_str.length() > 50 {
      token_str[0:50].to_string() + "..."
    } else {
      token_str
    }
  }
  println("   Access Token (preview): \{access_token_preview}")

  // Success
  print_separator("🎉 Authentication Complete!")
  println("You have successfully authenticated with Google using OAuth2!")
  println("")
  println("📖 For more information, see:")
  println("   - examples/google/README.md")
  println("   - lib/providers/google/README.md")
  println("")
}
