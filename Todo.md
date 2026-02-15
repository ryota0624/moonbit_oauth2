# goal

Native/JSで動くauth2のクライアントライブラリを実装する。
実装は https://docs.rs/oauth2 を参考にする。

参考: `docs/steering/20260215_oauth2_implementation_planning.md`

# Phase 1: MVP実装

## Step 1: プロジェクト構造とコア型定義
- [x] 実装計画を立てる（steeringドキュメント作成完了）
- [x] ディレクトリ構造の作成（lib/oauth2/, tests/oauth2/, examples/）
- [x] 基本的な型定義の実装
  - [x] ClientId, ClientSecret
  - [x] AuthUrl, TokenUrl, RedirectUrl
  - [x] Scope
  - [x] AccessToken, RefreshToken
  - [x] CsrfToken
  - [x] TokenResponse
- [x] エラー型の定義（OAuth2Error）
- [x] 基本型のユニットテスト（20テスト全て成功）

## Step 2: HTTPクライアント抽象化
- [x] mizchi/x依存関係の追加
  - [x] moon.mod.jsonの更新
  - [x] GitHubから直接取得する設定
- [x] HTTP型定義の実装
  - [x] HttpMethod enum
  - [x] HttpHeaders type alias
  - [x] HttpRequest/HttpResponse型定義
- [x] 基本的なHTTPクライアント機能
  - [x] OAuth2HttpClient構造体
  - [x] build_form_urlencoded_body関数
  - [x] build_basic_auth_header関数
  - [x] parse_oauth2_error関数（プレースホルダー）
- [x] HTTPクライアントの基本テスト（9テスト全て成功）
- [x] mizchi/xを使った実際のHTTP POST実装
  - [x] OAuth2HttpClient::postメソッドの非同期実装
  - [x] @http.postの統合
  - [x] エラーハンドリング

## Step 3: 認可コードフロー実装
- [x] AuthorizationRequest実装
  - [x] 認可URLの生成
  - [x] state（CSRF保護）パラメータの追加
  - [x] scopeのハンドリング
- [x] TokenRequest実装
  - [x] 認可コードからトークンへの交換
  - [x] リクエストボディの構築
- [x] TokenResponse実装
  - [x] JSONレスポンスのパース
  - [x] access_token, refresh_token, expires_in等の抽出
- [x] 認可コードフローの統合テスト
  - [x] 完全なフローのシミュレーション
  - [x] URL生成とトークン交換の連携テスト
  - [x] エラーハンドリングのテスト
  - [x] CSRF保護のテスト
- [ ] モックサーバーを使ったテスト

## Step 4: PKCE実装
- [ ] PkceCodeVerifier実装
  - [ ] ランダムなcode_verifierの生成
- [ ] PkceCodeChallenge実装
  - [ ] code_challengeの計算（SHA256）
  - [ ] code_challenge_methodの指定
- [ ] 認可コードフローへのPKCE統合
- [ ] PKCEのテスト

## Step 5: その他の認証フロー実装
- [ ] クライアント認証情報グラント
  - [ ] ClientCredentialsRequest実装
  - [ ] トークン取得フロー
  - [ ] テスト
- [ ] リソースオーナーパスワード認証情報グラント
  - [ ] PasswordRequest実装
  - [ ] ユーザー名/パスワードでのトークン取得
  - [ ] テスト

## Step 6: 統合テストと実例
- [ ] docker-compose.ymlでのテスト環境構築
  - [ ] モックOAuth2サーバーのセットアップ
- [ ] 実例の作成
  - [ ] GitHubでの使用例
  - [ ] Googleでの使用例
- [ ] ドキュメント整備
  - [ ] README.md
  - [ ] API Documentation
  - [ ] 使用例
- [ ] 完了ドキュメント作成

# Phase 2: 拡張機能（将来）
- [ ] デバイス認可フロー
- [ ] トークン内視検査（RFC 7662）
- [ ] トークン無効化（RFC 7009）
- [ ] トークンリフレッシュの自動化
- [ ] エラーリトライロジック
