# Steering: OAuth2クライアントライブラリ実装計画

## 目的・背景

Native/JSで動作するOAuth2クライアントライブラリをMoonBitで実装する。Rustのoauth2クレート（https://docs.rs/oauth2）を参考にし、RFC 6749に準拠した実装を目指す。

### なぜ必要か
- MoonBit向けの標準的なOAuth2ライブラリが存在しない
- Native/JS両環境で統一したAPIで認証処理を実装したい
- 型安全性の高い認証ライブラリが求められる

## ゴール

### 作業完了時の状態
1. OAuth2の主要な認証フローが実装されている
2. Native/JS両環境で動作する
3. RFC 6749準拠の実装
4. 型安全なAPI設計
5. テストコードとドキュメントが整備されている

### 成功の基準
- 各認証フローの基本的な動作が確認できる
- Native/JSでテストが通る
- 実際のOAuth2プロバイダ（GitHub、Google等）と連携できる

## アプローチ

### 参考実装
Rust oauth2クレート（https://docs.rs/oauth2）の設計を参考にする。

### 技術的アプローチ
1. **段階的実装**: 最もシンプルなフローから実装し、徐々に複雑なフローを追加
2. **型安全性**: MoonBitの型システムを活用し、コンパイル時のエラー検出を最大化
3. **プラットフォーム抽象化**: HTTPクライアント層を抽象化し、Native/JSで異なる実装を使用

## スコープ

### 含むもの（Phase 1: MVP）

#### コア機能
1. **基本的なデータ型**
   - ClientId, ClientSecret
   - AuthUrl, TokenUrl
   - RedirectUrl
   - Scope
   - AccessToken, RefreshToken
   - CsrfToken

2. **認証フロー（優先順位順）**
   - 認可コードグラント（Authorization Code Grant）
   - 認可コードグラント with PKCE
   - クライアント認証情報グラント（Client Credentials Grant）
   - リソースオーナーパスワード認証情報グラント（Resource Owner Password Credentials Grant）

3. **基本的なリクエスト/レスポンス処理**
   - AuthorizationRequest: 認可URLの生成
   - TokenRequest: トークン取得リクエスト
   - TokenResponse: トークンレスポンスのパース

4. **HTTPクライアント抽象化**
   - Native環境用HTTPクライアント（curlまたは類似ライブラリ）
   - JS環境用HTTPクライアント（fetch API）

5. **エラーハンドリング**
   - RFC 6749のエラーレスポンス処理
   - ネットワークエラー処理

### 含まないもの（Phase 2以降）
- インプリシットグラント（セキュリティ上非推奨）
- デバイス認可フロー（Device Authorization Flow）
- トークン内視検査（RFC 7662）
- トークン無効化（RFC 7009）
- トークンリフレッシュの自動化
- 高度なエラーリトライロジック

### 技術的制約
- MoonBitの現在の機能範囲内で実装
- 外部依存は最小限に抑える
- HTTPクライアントは既存のMoonBitライブラリを活用

## 影響範囲

### 新規作成ファイル（予定）
```
lib/
├── oauth2/
│   ├── moon.pkg              # パッケージ定義
│   ├── types.mbt             # 基本的な型定義
│   ├── client.mbt            # OAuth2クライアント
│   ├── auth_code.mbt         # 認可コードフロー
│   ├── client_credentials.mbt # クライアント認証情報フロー
│   ├── password.mbt          # パスワードフロー
│   ├── pkce.mbt              # PKCE実装
│   ├── token.mbt             # トークン処理
│   ├── error.mbt             # エラー型
│   ├── http_client.mbt       # HTTPクライアント抽象化
│   └── http_client_native.mbt # Native実装
│   └── http_client_js.mbt    # JS実装
│
tests/
├── oauth2/
│   ├── moon.pkg              # テストパッケージ定義
│   ├── types_test.mbt        # 型のテスト
│   ├── auth_code_test.mbt    # 認可コードフローテスト
│   └── ...
│
examples/
├── github_oauth/             # GitHubでの使用例
└── google_oauth/             # Googleでの使用例
```

### 変更ファイル
- `moon.mod.json`: モジュールメタデータの更新、依存関係追加

## 実装計画

### Step 1: プロジェクト構造とコア型定義（1-2日）
- ディレクトリ構造の作成
- 基本的な型定義（ClientId, TokenResponse等）
- エラー型の定義

### Step 2: HTTPクライアント抽象化（2-3日）
- HTTPクライアントインターフェースの設計
- Native実装
- JS実装
- 基本的なテスト

### Step 3: 認可コードフロー実装（3-4日）
- AuthorizationRequest実装
- TokenRequest/TokenResponse実装
- CSRF保護の実装
- テストの作成

### Step 4: PKCE実装（2-3日）
- PkceCodeChallenge/Verifier実装
- 認可コードフローへの統合
- テスト

### Step 5: その他フロー実装（3-4日）
- クライアント認証情報フロー
- パスワードフロー
- それぞれのテスト

### Step 6: 統合テストと実例（2-3日）
- 実際のOAuth2プロバイダを使った統合テスト
- 使用例の作成（GitHub、Google）
- ドキュメント整備

## リスクと対策

### リスク1: MoonBitのHTTPライブラリが未成熟
- **対策**: 必要に応じてFFI経由で既存のHTTPライブラリを使用

### リスク2: Native/JSでの動作の違い
- **対策**: 抽象化層を厚くし、プラットフォーム固有の実装を分離

### リスク3: OAuth2プロバイダごとの実装の差異
- **対策**: まずは標準的なフローを実装し、プロバイダ固有の拡張は後回し

## 参考資料
- [RFC 6749: The OAuth 2.0 Authorization Framework](https://datatracker.ietf.org/doc/html/rfc6749)
- [RFC 7636: Proof Key for Code Exchange (PKCE)](https://datatracker.ietf.org/doc/html/rfc7636)
- [Rust oauth2 crate](https://docs.rs/oauth2/latest/oauth2/)
- [MoonBit Documentation](https://docs.moonbitlang.com)

## 次のステップ
1. このsteeringドキュメントのレビューと承認
2. プロジェクト構造の作成
3. コア型定義の実装開始
