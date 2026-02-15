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
- [ ] HTTPクライアントインターフェースの設計
  - [ ] HttpClient trait/インターフェース定義
  - [ ] HttpRequest/HttpResponse型定義
- [ ] Native環境用HTTPクライアント実装
  - [ ] FFI経由でのHTTPクライアント実装検討
  - [ ] または既存MoonBitライブラリの調査と活用
- [ ] JS環境用HTTPクライアント実装（fetch API）
- [ ] HTTPクライアントの基本テスト

## Step 3: 認可コードフロー実装
- [ ] AuthorizationRequest実装
  - [ ] 認可URLの生成
  - [ ] state（CSRF保護）パラメータの追加
  - [ ] scopeのハンドリング
- [ ] TokenRequest実装
  - [ ] 認可コードからトークンへの交換
  - [ ] リクエストボディの構築
- [ ] TokenResponse実装
  - [ ] JSONレスポンスのパース
  - [ ] access_token, refresh_token, expires_in等の抽出
- [ ] 認可コードフローの統合テスト
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
