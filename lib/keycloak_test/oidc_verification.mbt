// Keycloak OIDC 検証スクリプト
// MoonBit の OIDC 実装を使用して Keycloak の OIDC 機能をテストします

///|
/// 環境変数から設定を読み込む
struct OidcConfig {
  realm : String
  base_url : String
  token_endpoint : String
  auth_endpoint : String
  userinfo_endpoint : String
  client_id : String
  client_secret : String
  test_username : String
  test_password : String
}

///|
/// 環境変数またはデフォルト値から設定を構築
fn OidcConfig::from_env() -> OidcConfig {
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
  let userinfo_endpoint = "\{base_url}/protocol/openid-connect/userinfo"
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

  OidcConfig::{
    realm,
    base_url,
    token_endpoint,
    auth_endpoint,
    userinfo_endpoint,
    client_id,
    client_secret,
    test_username,
    test_password,
  }
}

///|
/// テスト結果を表示
fn print_test_result(
  test_name : String,
  success : Bool,
  message : String
) -> Unit {
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
fn print_test_separator(title : String) -> Unit {
  println("")
  println("============================================================")
  println(title)
  println("============================================================")
}

///|
/// ID Token 取得テスト（Password Grant Flow）
async fn test_id_token_acquisition(config : OidcConfig) -> Unit {
  print_test_separator("Test 1: ID Token取得（Password Grant Flow）")
  println("Token Endpoint: \{config.token_endpoint}")
  println("Client ID: \{config.client_id}")
  println("Username: \{config.test_username}")
  println("Scopes: openid, profile, email")
  println("")

  // OAuth2 型を構築
  let token_url = @oauth2.TokenUrl::new(config.token_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let client_secret = @oauth2.ClientSecret::new(config.client_secret)
  let scopes = [
    @oauth2.Scope::openid(),
    @oauth2.Scope::profile(),
    @oauth2.Scope::email(),
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
      print_test_result("トークン取得", true, "")

      // id_token フィールドの確認
      match response.id_token() {
        Some(id_token_str) => {
          print_test_result("id_token フィールド存在", true, "")

          // ID Token のプレビュー表示
          let token_preview = if id_token_str.length() > 50 {
            id_token_str[0:50].to_string() + "..."
          } else {
            id_token_str
          }
          println("")
          println("📋 ID Token (先頭50文字):")
          println("  \{token_preview}")

          // JWT 形式の確認（3部分に分割できるか）
          let parts = id_token_str.split(".").collect()
          if parts.length() == 3 {
            print_test_result("JWT 形式（3部分構造）", true, "")
          } else {
            print_test_result(
              "JWT 形式（3部分構造）",
              false,
              "部分数: \{parts.length()}",
            )
          }

          // ID Token のパースを試みる
          println("")
          println("📋 ID Token パース:")
          match @oidc.IdToken::parse(id_token_str) {
            Ok(id_token) => {
              print_test_result("ID Token パース", true, "")

              // 必須クレームの確認
              let iss = id_token.issuer()
              let sub = id_token.subject()
              let aud = id_token.audience()
              let exp = id_token.expiration()
              let iat = id_token.issued_at()

              println("")
              println("📋 ID Token クレーム:")
              println("  iss (Issuer): \{iss}")
              println("  sub (Subject): \{sub}")
              println("  aud (Audience): \{aud}")
              println("  exp (Expiration): \{exp}")
              println("  iat (Issued At): \{iat}")

              // クレームの存在確認
              print_test_result("iss クレーム", iss != "", "")
              print_test_result("sub クレーム", sub != "", "")
              print_test_result("aud クレーム", aud != "", "")
              print_test_result("exp クレーム", exp > 0L, "")
              print_test_result("iat クレーム", iat > 0L, "")

              // issuer の妥当性確認（Keycloak の base_url を含むか）
              let valid_issuer = iss.contains(config.realm)
              print_test_result(
                "Issuer 妥当性",
                valid_issuer,
                "realm が含まれる: \{valid_issuer}",
              )

              // audience の妥当性確認（client_id と一致するか）
              let valid_audience = aud == config.client_id
              print_test_result(
                "Audience 妥当性",
                valid_audience,
                "client_id と一致: \{valid_audience}",
              )

              // オプションクレームの確認
              println("")
              println("📋 オプションクレーム:")

              match id_token.email() {
                Some(email) => {
                  println("  email: \{email}")
                  print_test_result("email クレーム", true, "")
                }
                None => print_test_result("email クレーム", false, "存在しません")
              }

              match id_token.name() {
                Some(name) => {
                  println("  name: \{name}")
                  print_test_result("name クレーム", true, "")
                }
                None => print_test_result("name クレーム", false, "存在しません")
              }

              match id_token.nonce() {
                Some(nonce) => {
                  println("  nonce: \{nonce}")
                  print_test_result("nonce クレーム", true, "")
                }
                None => print_test_result("nonce クレーム", false, "存在しません")
              }
            }
            Err(error) =>
              print_test_result("ID Token パース", false, error.message())
          }
        }
        None =>
          print_test_result(
            "id_token フィールド存在",
            false,
            "TokenResponse に id_token が含まれていません",
          )
      }
    }
    Err(error) =>
      print_test_result("トークン取得", false, error.message())
  }
}

///|
/// UserInfo Endpoint テスト
async fn test_userinfo_endpoint(config : OidcConfig) -> Unit {
  print_test_separator("Test 2: UserInfo Endpoint")
  println("UserInfo Endpoint: \{config.userinfo_endpoint}")
  println("")

  // まずトークンを取得
  println("📋 Access Token 取得中...")
  let token_url = @oauth2.TokenUrl::new(config.token_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let client_secret = @oauth2.ClientSecret::new(config.client_secret)
  let scopes = [
    @oauth2.Scope::openid(),
    @oauth2.Scope::profile(),
    @oauth2.Scope::email(),
  ]

  let request = @oauth2.PasswordRequest::new(
    token_url,
    client_id,
    Some(client_secret),
    config.test_username,
    config.test_password,
    scopes,
  )

  let http_client = @oauth2.OAuth2HttpClient::new()
  let result = request.execute(http_client)

  match result {
    Ok(response) => {
      print_test_result("Access Token 取得", true, "")

      // ID Token の sub を取得（後で比較）
      let id_token_sub = match response.id_token() {
        Some(id_token_str) =>
          match @oidc.IdToken::parse(id_token_str) {
            Ok(id_token) => Some(id_token.subject())
            Err(_) => None
          }
        None => None
      }

      // UserInfo リクエストを作成
      println("")
      println("📋 UserInfo リクエスト送信中...")
      let userinfo_url = @oidc.UserInfoUrl::new(config.userinfo_endpoint)
      let userinfo_request = @oidc.UserInfoRequest::new(
        userinfo_url,
        response.access_token(),
      )

      // UserInfo を取得
      let http_client2 = @oauth2.OAuth2HttpClient::new()
      let userinfo_result = userinfo_request.execute(http_client2)

      match userinfo_result {
        Ok(userinfo) => {
          print_test_result("UserInfo 取得", true, "")

          println("")
          println("📋 UserInfo:")
          let userinfo_sub = userinfo.sub
          println("  sub: \{userinfo_sub}")

          match userinfo.name {
            Some(name) => println("  name: \{name}")
            None => ()
          }

          match userinfo.email {
            Some(email) => println("  email: \{email}")
            None => ()
          }

          match userinfo.email_verified {
            Some(verified) => println("  email_verified: \{verified}")
            None => ()
          }

          // sub の存在確認
          print_test_result("sub フィールド", userinfo_sub != "", "")

          // ID Token の sub と一致するか確認
          match id_token_sub {
            Some(token_sub) => {
              let sub_match = userinfo_sub == token_sub
              print_test_result(
                "sub 一致（ID Token vs UserInfo）",
                sub_match,
                "一致: \{sub_match}",
              )
            }
            None =>
              print_test_result(
                "sub 一致（ID Token vs UserInfo）",
                false,
                "ID Token が取得できませんでした",
              )
          }

          // オプションフィールドの確認
          let has_name = match userinfo.name {
            Some(_) => true
            None => false
          }
          print_test_result("name フィールド", has_name, "")

          let has_email = match userinfo.email {
            Some(_) => true
            None => false
          }
          print_test_result("email フィールド", has_email, "")
        }
        Err(error) =>
          print_test_result("UserInfo 取得", false, error.message())
      }
    }
    Err(error) => print_test_result("Access Token 取得", false, error.message())
  }
}

///|
/// nonce パラメータテスト
fn test_nonce_parameter(config : OidcConfig) -> Unit {
  print_test_separator("Test 3: nonce パラメータ")
  println("Authorization Endpoint: \{config.auth_endpoint}")
  println("")

  // nonce を生成
  let nonce = @oauth2.generate_nonce()
  println("📋 生成された nonce:")
  println("  \{nonce}")
  print_test_result("nonce 生成", true, "")

  // Authorization URL を構築（nonce 付き）
  let auth_url = @oauth2.AuthUrl::new(config.auth_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let redirect_uri = @oauth2.RedirectUrl::new("http://localhost:3000/callback")
  let scopes = [@oauth2.Scope::openid(), @oauth2.Scope::profile()]
  let state = @oauth2.generate_csrf_token()
  let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
  let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(
    pkce_verifier,
  )

  // nonce を含む Authorization Request を作成
  let mut request = @oauth2.AuthorizationRequest::new_with_pkce(
    auth_url, client_id, redirect_uri, scopes, state, pkce_challenge,
  )
  request = request.with_nonce(nonce)

  // Authorization URL を構築
  let authorization_url = request.build_authorization_url()

  println("")
  println("📋 生成された Authorization URL:")
  println("\{authorization_url}")
  println("")

  // URL に nonce が含まれているか確認
  let has_nonce = authorization_url.contains("nonce=")
  print_test_result("nonce パラメータ存在", has_nonce, "")

  // その他のパラメータも確認
  let has_client_id = authorization_url.contains("client_id=")
  let has_redirect = authorization_url.contains("redirect_uri=")
  let has_scope = authorization_url.contains("scope=")
  let has_openid = authorization_url.contains("openid")

  print_test_result("client_id パラメータ", has_client_id, "")
  print_test_result("redirect_uri パラメータ", has_redirect, "")
  print_test_result("scope パラメータ", has_scope, "")
  print_test_result("openid スコープ", has_openid, "")
}

///|
/// トークンレスポンスヘルパー関数テスト
async fn test_token_response_helpers(config : OidcConfig) -> Unit {
  print_test_separator("Test 4: TokenResponse ヘルパー関数")
  println("")

  // トークンを取得
  println("📋 トークン取得中...")
  let token_url = @oauth2.TokenUrl::new(config.token_endpoint)
  let client_id = @oauth2.ClientId::new(config.client_id)
  let client_secret = @oauth2.ClientSecret::new(config.client_secret)
  let scopes = [@oauth2.Scope::openid()]

  let request = @oauth2.PasswordRequest::new(
    token_url,
    client_id,
    Some(client_secret),
    config.test_username,
    config.test_password,
    scopes,
  )

  let http_client = @oauth2.OAuth2HttpClient::new()
  let result = request.execute(http_client)

  match result {
    Ok(response) => {
      print_test_result("トークン取得", true, "")

      // parse_id_token_from_response テスト（Option を返す）
      println("")
      println("📋 parse_id_token_from_response テスト:")
      match @oidc.parse_id_token_from_response(response) {
        Ok(Some(id_token)) => {
          print_test_result("parse_id_token_from_response", true, "")
          println("  sub: \{id_token.subject()}")
        }
        Ok(None) =>
          print_test_result(
            "parse_id_token_from_response",
            false,
            "id_token が存在しません",
          )
        Err(error) =>
          print_test_result(
            "parse_id_token_from_response",
            false,
            error.message(),
          )
      }

      // get_id_token_from_response テスト（Error を返す）
      println("")
      println("📋 get_id_token_from_response テスト:")
      match @oidc.get_id_token_from_response(response) {
        Ok(id_token) => {
          print_test_result("get_id_token_from_response", true, "")
          println("  sub: \{id_token.subject()}")
        }
        Err(error) =>
          print_test_result(
            "get_id_token_from_response",
            false,
            error.message(),
          )
      }
    }
    Err(error) => print_test_result("トークン取得", false, error.message())
  }
}

///|
/// メインエントリポイント
async fn run_oidc_verification() -> Unit {
  println(
    "\u{1b}[1;36m============================================================\u{1b}[0m",
  )
  println("\u{1b}[1;36mKeycloak OIDC 検証スクリプト (MoonBit)\u{1b}[0m")
  println(
    "\u{1b}[1;36m============================================================\u{1b}[0m",
  )
  println("")

  // 設定を読み込み
  let config = OidcConfig::from_env()

  // Client Secret が設定されているか確認
  if config.client_secret == "" {
    println(
      "\u{1b}[31m✗ エラー: CLIENT_SECRET が設定されていません\u{1b}[0m",
    )
    println("")
    println("以下のコマンドを実行してください:")
    println("  export CLIENT_SECRET=\"your-client-secret-here\"")
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
  println("  UserInfo Endpoint: \{config.userinfo_endpoint}")
  println("  Client ID: \{config.client_id}")
  println("  Client Secret: \{secret_preview}")
  println("  Test User: \{config.test_username}")
  println("")

  // 各テストを実行
  test_id_token_acquisition(config)
  test_userinfo_endpoint(config)
  test_nonce_parameter(config)
  test_token_response_helpers(config)

  // サマリー
  print_test_separator("テスト完了")
  println("")
  println(
    "✓ MoonBit OIDC 実装で Keycloak の動作を検証しました",
  )
  println("")
  println(
    "📖 詳細な手順は docs/verification/oidc_verification_guide.md を参照",
  )
  println("")
}
