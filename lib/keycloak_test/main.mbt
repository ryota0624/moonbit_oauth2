// Keycloak OAuth2 検証スクリプト
// MoonBit の OAuth2 実装を使用して Keycloak の各フローをテストします

///|
/// 環境変数から設定を読み込む
struct Config {
  realm : String
  base_url : String
  token_endpoint : String
  auth_endpoint : String
  client_id : String
  client_secret : String
  test_username : String
  test_password : String
}

///|
/// 環境変数またはデフォルト値から設定を構築
fn Config::from_env() -> Config {
  let realm = match @sys.get_env_var("KEYCLOAK_REALM") {
    Some(v) => v
    None => "test-realm"
  }
  let base_url = match @sys.get_env_var("KEYCLOAK_BASE_URL") {
    Some(v) => v
    None => "http://localhost:8080/realms/\{realm}"
  }
  let token_endpoint = match @sys.get_env_var("TOKEN_ENDPOINT") {
    Some(v) => v
    None => "\{base_url}/protocol/openid-connect/token"
  }
  let auth_endpoint = "\{base_url}/protocol/openid-connect/auth"
  let client_id = match @sys.get_env_var("CLIENT_ID") {
    Some(v) => v
    None => "test-client"
  }
  let client_secret = match @sys.get_env_var("CLIENT_SECRET") {
    Some(v) => v
    None => ""
  }
  let test_username = match @sys.get_env_var("TEST_USERNAME") {
    Some(v) => v
    None => "testuser"
  }
  let test_password = match @sys.get_env_var("TEST_PASSWORD") {
    Some(v) => v
    None => "testpass123"
  }

  Config::{
    realm,
    base_url,
    token_endpoint,
    auth_endpoint,
    client_id,
    client_secret,
    test_username,
    test_password,
  }
}

///|
/// テスト結果を表示
fn print_result(test_name : String, success : Bool, message : String) -> Unit {
  let status = if success { "✓ 成功" } else { "✗ 失敗" }
  let color = if success { "\u{1b}[32m" } else { "\u{1b}[31m" }
  let reset = "\u{1b}[0m"
  println("\{color}[\{status}]\{reset} \{test_name}")
  if message != "" {
    println("  \{message}")
  }
}

///|
/// セパレーターを表示
fn print_separator(title : String) -> Unit {
  println("")
  println("============================================================")
  println(title)
  println("============================================================")
}

///|
/// Client Credentials Flow のテスト
async fn test_client_credentials(config : Config) -> Unit {
  print_separator("Test 1: Client Credentials Flow")
  println("Token Endpoint: \{config.token_endpoint}")
  println("Client ID: \{config.client_id}")
  println("")

  // OAuth2 型を構築
  let token_url = @oauth2.TokenUrl::new(config.token_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let client_secret = @oauth2.ClientSecret::new(config.client_secret)
  let scopes = [@oauth2.Scope::new("openid")]

  // ClientCredentialsRequest を作成
  let request = @oauth2.ClientCredentialsRequest::new(
    token_url,
    client_id,
    client_secret,
    scopes,
  )

  println("リクエスト送信中...")

  // HTTP クライアントを作成して実行
  let http_client = @oauth2.OAuth2HttpClient::new()
  let result = request.execute(http_client)

  match result {
    Ok(response) => {
      // 成功レスポンスの検証
      print_result("トークン取得", true, "")
      println("")
      println("📋 トークン情報:")
      println("  Token Type: \{response.token_type()}")

      match response.expires_in() {
        Some(expires) => println("  Expires In: \{expires}秒")
        None => println("  Expires In: 指定なし")
      }

      let token_str = response.access_token().to_string()
      let token_preview = if token_str.length() > 50 {
        token_str[0:50].to_string() + "..."
      } else {
        token_str
      }
      println("  Access Token (先頭50文字): \{token_preview}")

      match response.scope() {
        Some(scope) => println("  Scope: \{scope}")
        None => ()
      }

      // トークンが JWT 形式かチェック
      let is_jwt = token_str.contains(".")
      print_result("JWT 形式", is_jwt, "")

      // 有効期限のチェック
      match response.expires_in() {
        Some(expires) => {
          let valid_expiry = expires > 0 && expires <= 3600
          print_result("有効期限", valid_expiry, "expires_in=\{expires}秒")
        }
        None => print_result("有効期限", false, "有効期限が指定されていません")
      }
    }
    Err(error) => {
      print_result("Client Credentials Flow", false, error.message())
    }
  }
}

///|
/// Password Grant Flow のテスト
async fn test_password_grant(config : Config) -> Unit {
  print_separator("Test 2: Password Grant Flow")
  println("Token Endpoint: \{config.token_endpoint}")
  println("Client ID: \{config.client_id}")
  println("Username: \{config.test_username}")
  println("")

  // OAuth2 型を構築
  let token_url = @oauth2.TokenUrl::new(config.token_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let client_secret = @oauth2.ClientSecret::new(config.client_secret)
  let scopes = [
    @oauth2.Scope::new("openid"),
    @oauth2.Scope::new("profile"),
    @oauth2.Scope::new("email"),
  ]

  // PasswordRequest を作成
  let request = @oauth2.PasswordRequest::new(
    token_url,
    client_id,
    Some(client_secret),
    config.test_username,
    config.test_password,
    scopes,
  )

  println("リクエスト送信中...")

  // HTTP クライアントを作成して実行
  let http_client = @oauth2.OAuth2HttpClient::new()
  let result = request.execute(http_client)

  match result {
    Ok(response) => {
      // 成功レスポンスの検証
      print_result("トークン取得", true, "")
      println("")
      println("📋 トークン情報:")
      println("  Token Type: \{response.token_type()}")

      match response.expires_in() {
        Some(expires) => println("  Expires In: \{expires}秒")
        None => println("  Expires In: 指定なし")
      }

      let token_str = response.access_token().to_string()
      let token_preview = if token_str.length() > 50 {
        token_str[0:50].to_string() + "..."
      } else {
        token_str
      }
      println("  Access Token (先頭50文字): \{token_preview}")

      match response.refresh_token() {
        Some(rt) => {
          let rt_str = rt.to_string()
          let rt_preview = if rt_str.length() > 50 {
            rt_str[0:50].to_string() + "..."
          } else {
            rt_str
          }
          println("  Refresh Token (先頭50文字): \{rt_preview}")
        }
        None => ()
      }

      match response.scope() {
        Some(scope) => println("  Scope: \{scope}")
        None => ()
      }

      // 各トークンの検証
      print_result("Access Token 取得", true, "")
      let has_refresh_token = match response.refresh_token() {
        Some(_) => true
        None => false
      }
      print_result("Refresh Token 取得", has_refresh_token, "")

      // トークンが JWT 形式かチェック
      let is_jwt = token_str.contains(".")
      print_result("JWT 形式", is_jwt, "")

      // UserInfo エンドポイントでユーザー情報を取得
      println("")
      println("📋 UserInfo エンドポイントでユーザー情報を取得:")
      let userinfo_url = "\{config.base_url}/protocol/openid-connect/userinfo"
      println("  URL: \{userinfo_url}")

      let headers : Map[String, String] = {
        "Authorization": "Bearer \{token_str}",
        "Accept": "application/json",
      }

      let (resp, body) = @http.get(userinfo_url, headers~)
      if resp.code == 200 {
        print_result("UserInfo 取得", true, "")
        println("")
        println("  ユーザー情報:")
        let body_str = body.text()
        println("  \{body_str}")

        // JSONから基本情報を抽出（簡易パース）
        if body_str.contains("\"sub\"") {
          print_result("sub (ユーザーID) 存在", true, "")
        }
        if body_str.contains("\"preferred_username\"") {
          print_result("preferred_username 存在", true, "")
        }
        if body_str.contains("\"email\"") {
          print_result("email 存在", true, "")
        }
      } else {
        print_result("UserInfo 取得", false, "HTTP \{resp.code}")
      }
    }
    Err(error) => {
      print_result("Password Grant Flow", false, error.message())
    }
  }
}

///|
/// Authorization Code Flow の準備テスト（認可 URL 生成）
fn test_authorization_code_preparation(config : Config) -> Unit {
  print_separator("Test 3: Authorization Code Flow (準備)")
  println("Authorization Endpoint: \{config.auth_endpoint}")
  println("Client ID: \{config.client_id}")
  println("")

  // OAuth2 型を構築
  let auth_url = @oauth2.AuthUrl::new(config.auth_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let redirect_uri = @oauth2.RedirectUrl::new("http://localhost:3000/callback")
  let scopes = [
    @oauth2.Scope::new("openid"),
    @oauth2.Scope::new("profile"),
    @oauth2.Scope::new("email"),
  ]
  let state = @oauth2.generate_csrf_token()

  // PKCE を生成
  let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
  let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(pkce_verifier)

  // AuthorizationRequest を作成（PKCE 付き）
  let request = @oauth2.AuthorizationRequest::new_with_pkce(
    auth_url,
    client_id,
    redirect_uri,
    scopes,
    state,
    pkce_challenge,
  )

  // 認可 URL を構築
  let authorization_url = request.build_authorization_url()

  print_result("認可 URL 生成", true, "")
  println("")
  println("📋 生成された認可 URL:")
  println("\{authorization_url}")
  println("")
  println("🌐 ブラウザでの動作確認手順:")
  println("  1. 上記 URL をブラウザで開く")
  println("  2. Keycloak ログイン画面が表示される")
  println("  3. \{config.test_username} / \{config.test_password} でログイン")
  println("  4. リダイレクト URI にコールバックされる")
  println("  5. URL から認可コード (code) を取得")
  println("")

  // URL の構造チェック
  let has_client_id = authorization_url.contains("client_id=")
  let has_redirect = authorization_url.contains("redirect_uri=")
  let has_scope = authorization_url.contains("scope=")
  let has_state = authorization_url.contains("state=")
  let has_pkce = authorization_url.contains("code_challenge=")

  print_result("client_id パラメータ", has_client_id, "")
  print_result("redirect_uri パラメータ", has_redirect, "")
  print_result("scope パラメータ", has_scope, "")
  print_result("state パラメータ", has_state, "")
  print_result("PKCE code_challenge", has_pkce, "")
}

///|
/// エラーハンドリングのテスト
async fn test_error_handling(config : Config) -> Unit {
  print_separator("Test 4: エラーハンドリング")
  println("無効な認証情報でエラーレスポンスを検証")
  println("")

  // 無効な Client Secret でテスト
  let token_url = @oauth2.TokenUrl::new(config.token_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let invalid_secret = @oauth2.ClientSecret::new("invalid-secret")
  let scopes = [@oauth2.Scope::new("openid")]

  let request = @oauth2.ClientCredentialsRequest::new(
    token_url,
    client_id,
    invalid_secret,
    scopes,
  )

  let http_client = @oauth2.OAuth2HttpClient::new()
  let result = request.execute(http_client)

  match result {
    Ok(_) => print_result("無効な Client Secret", false, "エラーが返されるべき")
    Err(error) => {
      let msg = error.message()
      let msg_lower = msg.to_string().to_lower()
      // InvalidClient または Unauthorized エラーを期待
      if msg_lower.contains("invalid_client") || msg_lower.contains("unauthorized") {
        print_result("無効な Client Secret", true, "正しくエラーを返しました")
      } else {
        print_result("無効な Client Secret", false, "予期しないエラー: \{msg}")
      }
    }
  }

  // 無効なユーザー認証情報でテスト
  let client_secret = @oauth2.ClientSecret::new(config.client_secret)

  let password_request = @oauth2.PasswordRequest::new(
    token_url,
    client_id,
    Some(client_secret),
    config.test_username,
    "wrong-password",
    scopes,
  )

  let http_client2 = @oauth2.OAuth2HttpClient::new()
  let result2 = password_request.execute(http_client2)

  match result2 {
    Ok(_) => print_result("無効なパスワード", false, "エラーが返されるべき")
    Err(error) => {
      let msg = error.message()
      let msg_lower = msg.to_string().to_lower()
      // InvalidGrant エラーを期待
      if msg_lower.contains("invalid_grant") || msg_lower.contains("invalid user") {
        print_result("無効なパスワード", true, "正しくエラーを返しました")
      } else {
        print_result("無効なパスワード", false, "予期しないエラー: \{msg}")
      }
    }
  }
}

///|
/// メインエントリポイント
async fn main {
  println("\u{1b}[1;36m============================================================\u{1b}[0m")
  println("\u{1b}[1;36mKeycloak OAuth2 検証スクリプト (MoonBit)\u{1b}[0m")
  println("\u{1b}[1;36m============================================================\u{1b}[0m")
  println("")

  // 設定を読み込み
  let config = Config::from_env()

  // Client Secret が設定されているか確認
  if config.client_secret == "" {
    println("\u{1b}[31m✗ エラー: CLIENT_SECRET が設定されていません\u{1b}[0m")
    println("")
    println("以下のコマンドを実行してください:")
    println("  export CLIENT_SECRET=\"your-client-secret-here\"")
    println("")
    println("Client Secret は以下の方法で取得できます:")
    println("  1. ./scripts/setup_keycloak.sh を実行")
    println("  2. または Keycloak 管理コンソールから取得")
    println("     http://localhost:8080/admin")
    println("     → Clients → test-client → Credentials タブ")
    println("")
    return
  }

  let secret_preview = if config.client_secret.length() > 10 {
    config.client_secret[0:10].to_string() + "..."
  } else {
    "***"
  }

  println("📋 設定:")
  println("  Realm: \{config.realm}")
  println("  Base URL: \{config.base_url}")
  println("  Token Endpoint: \{config.token_endpoint}")
  println("  Client ID: \{config.client_id}")
  println("  Client Secret: \{secret_preview}")
  println("  Test User: \{config.test_username}")
  println("")

  // 各テストを実行
  test_client_credentials(config)
  test_password_grant(config)
  test_authorization_code_preparation(config)
  test_error_handling(config)

  // サマリー
  print_separator("テスト完了")
  println("")
  println("✓ MoonBit OAuth2 実装で Keycloak の動作を検証しました")
  println("")
  println("📖 詳細な手順は docs/testing/keycloak_verification_guide.md を参照")
  println("")
}
