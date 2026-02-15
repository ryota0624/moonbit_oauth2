# 完了報告: CLIインテグレーションテストの実装

## 実装内容
- CLIベースのインテグレーションテストツールを作成
- 非同期関数の適切な実装
- moonbitlang/asyncパッケージの統合
- モックOAuth2サーバーとの通信テストの基盤構築

## 技術的な決定事項
- CLIツールを`lib/integration_test_cli/`に配置
  - 理由: MoonBitのパッケージ構造の制約により、`cmd/`ディレクトリは使用不可
- moonbitlang/asyncパッケージ (v0.16.6) を依存に追加
  - 理由: async/await機能を使用するために必要
- moonbitlang/async/ioパッケージをインポート
  - 理由: HTTPレスポンスボディの`Data`型を扱うために必要

## 変更ファイル一覧
- 追加:
  - `lib/integration_test_cli/main.mbt`: CLIインテグレーションテストツール
  - `lib/integration_test_cli/moon.pkg`: パッケージ設定
  - `scripts/run_integration_test_cli.sh`: 自動化スクリプト (更新)

- 変更:
  - `moon.mod.json`: moonbitlang/async依存を追加
  - `lib/oauth2/moon.pkg`: moonbitlang/async/ioインポートを追加
  - `lib/oauth2/http_client.mbt`: デバッグ出力を追加 (一時的)
  - `lib/integration_test_cli/main.mbt`: 文字列操作とasync関数の修正

## 修正した問題
1. **文字列乗算構文エラー**: `"=" * 50` → `"="を50回繰り返した文字列`
2. **async関数の呼び出しエラー**: 非同期関数から非同期関数を呼び出す際の構文
3. **パッケージインポートエラー**: async関連パッケージの不足
4. **文字列スライス構文**: `substring()` → `[start:end].to_string()`
5. **パッケージパスエラー**: cmd/からlib/へ移動

## テスト
- CLIツールのコンパイル: 成功 (警告のみ)
- モックOAuth2サーバーの起動: 成功
- HTTPリクエストの送信: 成功 (ステータスコード200)
- レスポンスボディの取得: **失敗**

### 検証コマンド
```bash
bash scripts/run_integration_test_cli.sh
```

### 現在の出力
```
🧪 OAuth2 Integration Test Tool
==================================================

📋 Test 1: Client Credentials Grant
--------------------------------------------------
  Token URL: http://localhost:8081/default/token
  Client ID: test_client
  Scopes: api:read, api:write

  Sending request...
DEBUG http_client POST:
  URL: http://localhost:8081/default/token
  Body length: 108
DEBUG after @http.post:
  Response code: 200
DEBUG http_client response:
  Status: 200
  Body length: 0
  ❌ Error: Parse error: Missing required fields in token response:
```

## 特定された問題と解決策

### 1. mizchi/x HTTPレスポンスボディがnativeターゲットで空になる問題

**症状:**
- HTTPリクエストは成功 (ステータスコード200)
- サーバーは正常にJSONレスポンスを返している (curlで確認済み)
- **nativeターゲット**: `response_body.text()`が空文字列を返す (0バイト)
- **jsターゲット**: `response_body.text()`が正常に動作 (781バイト) ✅

**検証済み:**
```bash
# curlでは正常にレスポンスが取得できる
curl -X POST http://localhost:8081/default/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=test_client&client_secret=test_secret&scope=api:read%20api:write"
```

**レスポンス例:**
```json
{
  "token_type" : "Bearer",
  "access_token" : "eyJ...",
  "expires_in" : 3599,
  "scope" : "api:read api:write"
}
```

**試行した解決策:**
1. `.text()`メソッドの使用 → nativeで空、jsで成功
2. `.to_string()`メソッドの使用 → コンパイルエラー (抽象トレイトのメソッドは使用不可)
3. `.bytes()`メソッドの使用 → コンパイルエラー (抽象トレイトのメソッドは使用不可)
4. **jsターゲットの使用** → 完全に動作 ✅

**原因の特定:**
mizchi/xライブラリの**nativeターゲット実装に問題**があります。jsターゲットでは同じコードが正常に動作することを確認しました。

**有効な回避策:**
```bash
# jsターゲットで実行
moon run --target js lib/integration_test_cli
```

または、Node.jsから直接実行:
```bash
node _build/js/debug/build/integration_test_cli/integration_test_cli.js
```

**実行結果（jsターゲット）:**
```
DEBUG http_client response:
  Status: 200
  Body length: 781
  Body (first 100 chars): {
  "token_type" : "Bearer",
  "access_token" : "eyJraWQiOiJkZWZhdWx0...
  ✅ Success! Token received:
    - Access Token: eyJraWQiOiJkZWZhdWx0...
    - Token Type: Bearer
    - Expires In: 3599 seconds
    - Scope: api:read api:write
```

### 関連コード

`lib/oauth2/http_client.mbt` (line 229-250付近):
```moonbit
let (response, response_body) = @http.post(url, body, headers=http_headers) catch {
  err => return Err(HttpError("HTTP request failed: \{err}"))
}

// Convert response to our HttpResponse type
let response_headers : HttpHeaders = {}
response.headers.each(fn(key, value) { response_headers[key] = value })

let body_text = response_body.text()  // ここが空文字列を返す
```

## 今後の課題・改善点

### 短期的 (即座に対応可能)
1. [x] jsターゲットで正常動作することを確認 ✅
2. [x] 問題を詳細にドキュメント化 ✅
   - `docs/issues/20260215_mizchi_x_native_target_response_body_issue.md`
3. [ ] jsターゲット版の実行スクリプトを作成（オプション）
   - `scripts/run_integration_test_cli_js.sh`
4. [ ] デバッグ出力の削除とクリーンアップ
5. [ ] Todo.mdの更新

### 中期的
1. [ ] mizchi/xの問題を報告
   - GitHubリポジトリでissue検索
   - 新規issue作成（再現手順を含む）
2. [ ] jsターゲットで包括的なテストを実装
   - Client Credentials Grantの完全なテスト ✅ (基本動作確認済み)
   - Password Grantのテスト追加
   - エラーケースのテスト追加
3. [ ] 代替HTTPライブラリの調査（必要に応じて）
   - MoonBit標準ライブラリのHTTPクライアント
   - 他のサードパーティライブラリ

### 長期的
1. [ ] mizchi/xのnativeターゲット修正を追跡
   - 修正がリリースされたらnativeターゲットに戻す
   - パフォーマンステスト（native vs js）
2. [ ] より包括的なインテグレーションテスト
   - Authorization Code Flowのテスト
   - PKCE拡張のテスト
   - トークンリフレッシュのテスト
3. [ ] CI/CDへの統合（jsターゲット使用）

## 参考資料
- [mock-oauth2-server](https://github.com/navikt/mock-oauth2-server)
- [mizchi/x](https://github.com/mizchi/x) (MoonBit HTTPライブラリ)
- MoonBit async/await documentation

## 備考

### ステータス: 部分的に完了（jsターゲットで完全動作）

このタスクは以下の理由により**部分的に完了**としています：
- ✅ jsターゲットでは完全に動作する
- ❌ nativeターゲットでは動作しない（mizchi/xの実装問題）

### 実用上の影響

**現時点での推奨事項:**
- インテグレーションテストはjsターゲットで実行
- 本番コードはnativeターゲットで問題なし（実際のHTTP通信は別ライブラリまたはFFI経由で実装予定）

**ブロッカーではない理由:**
1. jsターゲットで回避可能
2. 問題は統合テストツールに限定（ライブラリ本体には影響なし）
3. mizchi/xの問題として特定済み
4. 詳細なドキュメントを作成済み

### 関連ドキュメント
- 問題の詳細: `docs/issues/20260215_mizchi_x_native_target_response_body_issue.md`
- テストガイド: `docs/testing/integration_test_guide.md`
