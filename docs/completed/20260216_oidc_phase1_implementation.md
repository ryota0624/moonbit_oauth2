# 完了報告: OIDC Phase 1 実装

実施日: 2026-02-16

## 実装内容

OpenID Connect (OIDC) Phase 1の基礎実装を完了しました。これには以下の機能が含まれます:

### 1. OIDCパッケージのセットアップ

- 新規パッケージ `lib/oidc/` を作成
- `moon.pkg` で `@oauth2` パッケージへの依存を設定
- Base64、JSON、暗号化ライブラリのインポート設定

### 2. ID Token型定義とパース実装

**新規ファイル**: `lib/oidc/id_token.mbt`

実装した機能:
- `IdToken` 構造体: JWT形式のID Tokenを表現
- `JwtHeader` 構造体: JWT header (alg, typ, kid)
- `IdTokenClaims` 構造体: OIDC標準クレーム（必須・推奨・オプション）
- `IdToken::parse()`: JWT文字列のパース
  - JWT文字列を3部分に分割 (header.payload.signature)
  - Base64URLデコード
  - JSONパース
- 各種getter関数: subject, issuer, audience, expiration等

技術的実装:
- MoonBit標準の `@json` パッケージを使用したJSONパース
- パターンマッチによる型安全なクレーム抽出
- Base64URLデコード（標準Base64への変換とパディング追加）

### 3. TokenResponse拡張

**変更ファイル**: `lib/oauth2/types.mbt`, `lib/oauth2/token_request.mbt`

- `TokenResponse` に `id_token: String?` フィールドを追加
- OIDC対応のため、生のJWT文字列として保存（循環依存回避）
- `parse_token_response()` で id_token フィールドをパース
- getter関数 `TokenResponse::id_token()` を追加

**新規ファイル**: `lib/oidc/token_response.mbt`

便利なヘルパー関数:
- `parse_id_token_from_response()`: TokenResponseからID Tokenをパース（Noneを許容）
- `get_id_token_from_response()`: TokenResponseからID Tokenを取得（エラーを返す）

### 4. UserInfo実装

**新規ファイル**: `lib/oidc/userinfo.mbt`

実装した機能:
- `UserInfo` 構造体: UserInfo Endpointからのユーザー情報
  - 必須: sub (ユーザーID)
  - オプション: name, email, picture, locale等
- `UserInfoUrl` 型: UserInfo Endpoint URL
- `UserInfoRequest` 構造体: UserInfo取得リクエスト
- `UserInfoRequest::execute()`: HTTP GETでUserInfo取得
  - Bearer Token認証
  - JSONレスポンスのパース
- 各種getter関数

**変更ファイル**: `lib/oauth2/http_client.mbt`

- `OAuth2HttpClient::get()` メソッドを追加
- HTTP GETリクエストのサポート（UserInfo Endpoint用）

### 5. nonce対応

**変更ファイル**: `lib/oauth2/types.mbt`

- `Nonce` 型を追加（CsrfTokenと同様の構造）
- OIDC スコープヘルパー関数を追加:
  - `Scope::openid()`
  - `Scope::profile()`
  - `Scope::email()`
  - `Scope::address()`
  - `Scope::phone()`

**変更ファイル**: `lib/oauth2/authorization_request.mbt`

- `AuthorizationRequest` に `nonce: Nonce?` フィールドを追加
- `generate_nonce()`: ランダムなnonce生成
- `AuthorizationRequest::with_nonce()`: 既存のrequestにnonceを追加
- `build_authorization_url()`: nonceをクエリパラメータに追加

### 6. OAuth2Error拡張

**変更ファイル**: `lib/oauth2/error.mbt`

外部パッケージからエラーを作成できるようにヘルパー関数を追加:
- `OAuth2Error::new_parse_error()`
- `OAuth2Error::new_http_error()`
- `OAuth2Error::new_other()`

## 技術的な決定事項

### 1. パッケージ構成

- **OIDC機能をOAuth2とは別パッケージとして実装**
  - 関心の分離（OAuth2=認可、OIDC=認証）
  - 依存関係の明確化
  - バンドルサイズの最適化

### 2. ID TokenのTokenResponseへの統合方法

- **生のJWT文字列として保存**
  - 循環依存を回避（OAuth2 → OIDC、OIDC → OAuth2は不可）
  - OIDCパッケージ側でパース
  - OAuth2パッケージはOIDCに依存しない

### 3. JSONパース

- **MoonBit標準の `@json` パッケージを使用**
  - 外部依存を最小化
  - パターンマッチによる型安全な実装
  - `True`/`False` コンストラクタを使用（`Boolean` ではない）

### 4. Base64URLデコード

- **標準Base64への変換**
  - `-` → `+`, `_` → `/`
  - パディング `=` を追加
  - `@base64.decode()` を使用

### 5. エラーハンドリング

- **既存のOAuth2Errorを再利用**
  - ヘルパー関数で外部パッケージから作成可能に
  - Phase 2でOIDC固有のエラーを追加予定

## 変更ファイル一覧

### 新規ファイル

```
lib/oidc/
├── moon.pkg                   # パッケージ定義
├── id_token.mbt              # ID Token型定義・パース（約300行）
├── token_response.mbt        # TokenResponseヘルパー（約30行）
└── userinfo.mbt              # UserInfo Endpoint（約280行）
```

### 変更ファイル

```
moon.mod.json                 # moonbitlang/x 依存追加
lib/oauth2/
├── types.mbt                 # Nonce型、TokenResponse拡張、OIDCスコープ
├── authorization_request.mbt # nonce対応
├── token_request.mbt         # id_tokenパース
├── http_client.mbt           # get()メソッド追加
├── error.mbt                 # ヘルパー関数追加
└── types_wbtest.mbt          # TokenResponse::new()更新
```

## テスト

- **OAuth2パッケージ**: 全124テストがパス
- **OIDCパッケージ**: ビルド成功、エラーなし
- Phase 1では統合テストは未実施（Phase 1の最終ステップで実施予定）

### 単体テスト（今後追加予定）

```
lib/oidc/
├── id_token_wbtest.mbt       # ID Tokenパーステスト
├── userinfo_wbtest.mbt       # UserInfoパーステスト
└── token_response_test.mbt   # ヘルパー関数テスト
```

## 今後の課題・改善点

### Phase 1 残り作業

- [ ] 統合テスト（Keycloak）の実装
  - OIDC Authorization Code Flow
  - ID Token受信・パース確認
  - UserInfo取得確認

### Phase 2: セキュリティ強化（今後実装）

- [ ] JWKS (JSON Web Key Set) の取得・管理
- [ ] ID Token署名検証（RS256）
- [ ] Claims検証（iss, aud, exp, nonce）
- [ ] OIDC固有のエラー型追加

### Phase 3: 高度な機能（今後実装）

- [ ] Discovery Document (`.well-known/openid-configuration`)
- [ ] Provider Metadata の利用
- [ ] OIDCClient統合API

### コード品質

- [ ] ユニットテストの追加
  - ID Tokenパーステスト（有効なJWT、無効なJWT）
  - UserInfoパーステスト
  - Base64URLデコードテスト
- [ ] スナップショットテストの追加
- [ ] テストカバレッジ向上（目標: 80%以上）

### ドキュメント

- [ ] OIDCの使い方ガイド
- [ ] サンプルコード
- [ ] APIリファレンス

## 参考資料

### 仕様

- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [RFC 7519 - JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519)

### 実装参考

- [oauth2-rs](https://github.com/ramosbugs/oauth2-rs) - Rust implementation
- [go-oidc](https://github.com/coreos/go-oidc) - Go implementation

## 成功の基準（Phase 1）

- [x] ID Tokenのパース・型定義が動作
- [x] TokenResponseがid_tokenフィールドを持つ
- [x] UserInfo Endpointの基本実装
- [x] nonceパラメータのサポート
- [x] OAuth2パッケージの全テストがパス
- [x] OIDCパッケージがエラーなしでビルド
- [ ] Keycloakとの統合テストがパス（次のステップ）

## 次のステップ

1. **Keycloak統合テスト** (`lib/keycloak_test/oidc_flow_test.mbt`)
   - Docker Composeでkeycloakを起動
   - OIDCフローのE2Eテスト
   - ID Token受信・パース確認
   - UserInfo取得確認

2. **ユニットテスト追加**
   - ID Token、UserInfoのパーステスト
   - エッジケースのテスト

3. **Phase 2の開始準備**
   - セキュリティ強化（署名検証）の計画
   - JWKS実装の設計

## 備考

- 警告: `unused_async` - 既存のOAuth2コードの問題（影響なし）
- 警告: `unused_package: moonbitlang/x/crypto` - Phase 2で使用予定
- 既知のビルドエラー: mizchi/x, moonbitlang/async の一部パッケージ（OIDC実装には影響なし）
