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
- [x] モックサーバーを使ったテスト
  - [x] mock-oauth2-serverのセットアップ
  - [x] 統合テストの実装
  - [x] 自動テストスクリプトの作成

## Step 4: PKCE実装
- [x] SHA256実装（RFC 6234準拠）
- [x] Base64URLエンコーディング（RFC 4648）
- [x] PkceCodeVerifier実装
  - [x] ランダムなcode_verifierの生成
  - [x] 43文字、unreserved文字セット
- [x] PkceCodeChallenge実装
  - [x] code_challengeの計算（SHA256）
  - [x] code_challenge_methodの指定（S256/Plain）
- [x] 認可コードフローへのPKCE統合
  - [x] AuthorizationRequest::new_with_pkce()
  - [x] TokenRequest::new_with_pkce()
- [x] PKCEのテスト
  - [x] RFC 7636テストベクター検証
  - [x] 統合テスト

## Step 5: その他の認証フロー実装
- [x] クライアント認証情報グラント
  - [x] ClientCredentialsRequest実装
  - [x] トークン取得フロー
  - [x] テスト（10テスト追加）
- [x] リソースオーナーパスワード認証情報グラント
  - [x] PasswordRequest実装
  - [x] ユーザー名/パスワードでのトークン取得
  - [x] テスト（15テスト追加）

## Step 6: 統合テストと実例
- [x] docker-compose.ymlでのテスト環境構築
  - [x] モックOAuth2サーバーのセットアップ（mock-oauth2-server）
  - [x] Keycloakのセットアップ（オプション）
- [x] 統合テストの実装
  - [x] Authorization Code Flowのテスト
  - [x] PKCEフローのテスト
  - [x] テスト自動化スクリプト
- [ ] 実例の作成
  - [ ] GitHubでの使用例
  - [ ] Googleでの使用例
- [ ] ドキュメント整備
  - [ ] README.md
  - [ ] API Documentation
  - [ ] 使用例
- [ ] 完了ドキュメント作成

# Phase 1.5: 実装の改善・修正（現状の不完全な箇所）

## セキュリティ改善（高優先度）
- [x] 暗号学的に安全な乱数生成器の実装 ✅ **完了**
  - [x] CSRF token生成の改善（authorization_request.mbt）
    - 改善前: LCGアルゴリズム（予測可能）
    - 改善後: moonbitlang/core/random（Chacha8 CSPRNG）
  - [x] PKCE code_verifier生成の改善（pkce.mbt）
    - 改善前: LCGアルゴリズム（暗号学的に安全でない）
    - 改善後: moonbitlang/core/random（Chacha8 CSPRNG）
  - [x] moon.pkgにrandomパッケージを追加
  - [x] 全128テスト成功確認
  - 実施工数: 1.5時間
  - 影響: 高（本番環境で安全に使用可能）

## chore: コードのリファクタリングとクリーンアップ（中優先度）
- [x] OAuth2HttpClientはprintデバッグの出力を内部フィールドで制御できる様にする ✅ **完了**
  - [x] debug: Boolフィールドを追加（_dummyから置き換え）
  - [x] デバッグ出力をこのフラグで制御（全17箇所）
  - [x] new_with_debug()コンストラクタ追加
  - [x] 全124テスト成功確認
  - 実施工数: 30分
 - [ ] jsonからの値の取り出しはjsonパッケージを使う様にする
 - [ ] sha256の実装はcryptoパッケージを使う様にする
 - [ ] Base64URLエンコードの実装はcodec/base64パッケージを使う様にする
 - [ ] ネストしたパターンマッチをguard節に置き換える

## HTTPクライアント機能拡張（中優先度）
- [ ] タイムアウト設定の実装
  - [ ] OAuth2HttpClientにタイムアウト設定を追加
  - [ ] デフォルト: 30秒
  - [ ] カスタマイズ可能にする
  - 推定工数: 2-3時間
  - 現状: mizchi/xのデフォルトに依存（長時間ハングの可能性）

- [ ] リトライロジックの実装
  - [ ] 一時的なネットワークエラーの自動リトライ
  - [ ] 指数バックオフ戦略
  - [ ] リトライ回数の設定（デフォルト: 3回）
  - [ ] リトライ対象エラーの選択（5xx、タイムアウト等）
  - 推定工数: 3-4時間

- [ ] HTTPクライアント設定の拡充
  - [ ] OAuth2HttpClient構造体に設定フィールド追加
    - timeout: Int?
    - max_retries: Int?
    - custom_headers: HttpHeaders?
    - user_agent: String?
  - [ ] OAuth2HttpClient::new_with_config()コンストラクタ
  - 推定工数: 2-3時間
  - 現状: _dummyフィールドのみ（http_client.mbt:5-8）

## Refresh Token機能実装（中優先度）
- [ ] RefreshTokenRequestの実装
  - [ ] refresh_tokenからaccess_tokenを取得
  - [ ] grant_type: "refresh_token"
  - [ ] スコープの更新（オプション）
  - [ ] テスト（8-10テスト）
  - 推定工数: 2-3時間
  - 現状: RefreshToken型は定義済みだが、リクエスト未実装

- [ ] トークンリフレッシュの自動化（オプション）
  - [ ] expires_inを監視
  - [ ] 自動的にrefresh_tokenを使用
  - [ ] トークン更新のコールバック
  - 推定工数: 3-4時間

## 統合テストの拡充（中優先度）
- [x] リクエスト構造テストの拡充 ✅ **完了**
  - [x] Client Credentials Grant（2テスト追加）
  - [x] Password Grant（2テスト追加）
  - [x] 全132テスト成功確認
  - 実施工数: 30分

- [x] CLIツールによる実際のHTTP通信テスト ✅ **完了**
  - [x] `cmd/integration_test/main.mbt`作成
  - [x] Client Credentials Grantの実通信テスト
  - [x] 実行スクリプト作成（`run_integration_test_cli.sh`）
  - [x] テストガイドドキュメント作成
  - 実施工数: 1時間

- [ ] さらなる統合テストの追加（低優先度）
  - [ ] Password Grantの実通信テスト
  - [ ] エラーレスポンステスト（4xx、5xx）
  - [ ] タイムアウトテスト
  - 推定工数: 2-3時間
  - 注記: MoonBitの非同期テストサポートが不明確なため、CLIツール経由で実装

## エラーハンドリングの改善（低優先度）
- [ ] より詳細なエラー情報
  - [ ] HTTPステータスコードの保持
  - [ ] レスポンスヘッダーの保持
  - [ ] タイムスタンプの記録
  - 推定工数: 2-3時間

- [ ] ロギング機能の追加
  - [ ] デバッグログ出力（オプション）
  - [ ] リクエスト/レスポンスのログ
  - [ ] エラーの詳細ログ
  - 推定工数: 2-3時間
  - 現状: ロギング機能なし（トラブルシューティング困難）

## ドキュメント整備（中優先度）
- [ ] README.md作成
  - [ ] プロジェクト概要
  - [ ] インストール方法
  - [ ] クイックスタート
  - [ ] サポートされているフロー一覧
  - [ ] 基本的な使用例
  - [ ] ライセンス情報
  - 推定工数: 2-3時間

- [ ] API Documentation作成
  - [ ] 各構造体の詳細説明
  - [ ] メソッドの使用方法
  - [ ] パラメータの説明
  - [ ] 戻り値の説明
  - [ ] エラーハンドリングの説明
  - 推定工数: 3-4時間

- [ ] チュートリアル作成
  - [ ] Authorization Code Flowのステップバイステップ
  - [ ] PKCEの使用方法
  - [ ] Client Credentialsの使用方法
  - [ ] エラーハンドリングのベストプラクティス
  - 推定工数: 2-3時間

- [ ] 実使用例（examples）作成
  - [ ] examples/github/: GitHub OAuth2連携
  - [ ] examples/google/: Google OAuth2連携
  - [ ] examples/client_credentials/: M2M認証サンプル
  - [ ] examples/password/: レガシーシステム連携（非推奨として明記）
  - 推定工数: 4-5時間

## コード品質改善（低優先度）
- [ ] OAuth2HttpClientのプレースホルダー削除
  - 現状: _dummy: Unit（http_client.mbt:6）
  - 改善: 実際の設定フィールドに置き換え

- [ ] 未使用のHttpMethodバリアント対応
  - 現状: GET、PUT、DELETEが未使用
  - 対応: 将来的に必要な場合に実装

- [ ] 予約語`method`の置き換え
  - 現状: pkce.mbtで使用（警告あり）
  - 改善: `challenge_method`等に名前変更

## テストカバレッジ向上（低優先度）
- [ ] エッジケーステストの追加
  - [ ] 空文字列のハンドリング
  - [ ] 非常に長い文字列のハンドリング
  - [ ] 特殊文字の完全なテスト
  - [ ] Unicode文字のテスト
  - 推定工数: 2-3時間

- [ ] 非同期テストの実装
  - [ ] execute()メソッドの実際の動作テスト
  - [ ] エラーハンドリングの動作テスト
  - 推定工数: 3-4時間
  - 現状: MoonBitテストフレームワークの非同期対応が不明

# Phase 2: 拡張機能（将来）

## Device Authorization Flow（RFC 8628）
- [ ] デバイス認可フローの実装
  - [ ] DeviceAuthorizationRequest
  - [ ] device_code、user_code、verification_uri
  - [ ] ポーリングロジック（interval、slow_down）
  - [ ] テスト
  - 対象: モバイルアプリ、TV、IoTデバイス
  - 推定工数: 5-6時間

## Token Introspection（RFC 7662）
- [ ] トークン内視検査の実装
  - [ ] IntrospectionRequest
  - [ ] トークンの有効性確認
  - [ ] active、scope、exp等の情報取得
  - [ ] テスト
  - 推定工数: 2-3時間

## Token Revocation（RFC 7009）
- [ ] トークン無効化の実装
  - [ ] RevocationRequest
  - [ ] access_tokenまたはrefresh_tokenの無効化
  - [ ] token_type_hint（オプション）
  - [ ] テスト
  - 推定工数: 2-3時間

## OpenID Connect対応
- [ ] OpenID Connectの実装
  - [ ] IDトークンのサポート
  - [ ] id_tokenのパース（JWT）
  - [ ] UserInfo endpoint
  - [ ] nonce、max_age等のパラメータ
  - [ ] テスト
  - 推定工数: 8-10時間

## その他の拡張機能
- [ ] JWTトークンのパース・検証
  - [ ] Base64URL decode
  - [ ] 署名検証（RS256、ES256等）
  - [ ] クレームの抽出
  - 推定工数: 4-5時間

- [ ] OAuth2クライアント証明書認証
  - [ ] mTLS（RFC 8705）
  - [ ] クライアント証明書の設定
  - 推定工数: 3-4時間

- [ ] Dynamic Client Registration（RFC 7591）
  - [ ] クライアント情報の動的登録
  - [ ] registration_endpoint
  - 推定工数: 3-4時間
