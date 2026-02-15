# Issue: mizchi/x HTTPレスポンスボディがnativeターゲットで空になる問題

## 概要

mizchi/x HTTPライブラリを使用した際、**nativeターゲットでは`response_body.text()`が空文字列を返す**が、**jsターゲットでは正常に動作する**という問題が発生しています。

## 環境

- **MoonBit バージョン**: (moon --version で確認)
- **OS**: macOS (Darwin 23.6.0)
- **mizchi/x バージョン**: 0.1.3
- **moonbitlang/async バージョン**: 0.16.6
- **moonbitlang/async/io**: インポート済み

## 問題の詳細

### 症状

HTTPリクエストは成功し、ステータスコード200が返されるものの、レスポンスボディを読み取ろうとすると空文字列になります。

#### nativeターゲット（問題あり）

```bash
moon run lib/integration_test_cli
# または
moon run --target native lib/integration_test_cli
```

**出力:**
```
DEBUG http_client POST:
  URL: http://localhost:8081/default/token
  Body length: 108
DEBUG after @http.post:
  Response code: 200
DEBUG http_client response:
  Status: 200
  Body length: 0           ← 空！
  ❌ Error: Parse error: Missing required fields in token response:
```

#### jsターゲット（正常動作）

```bash
moon run --target js lib/integration_test_cli
```

**出力:**
```
DEBUG http_client POST:
  URL: http://localhost:8081/default/token
  Body length: 108
DEBUG after @http.post:
  Response code: 200
DEBUG http_client response:
  Status: 200
  Body length: 781         ← 正常に取得！
  Body (first 100 chars): {
  "token_type" : "Bearer",
  "access_token" : "eyJraWQiOiJkZWZhdWx0IiwidHlwIjoiSldUIiwiYWxnIjoiUlM
  ✅ Success! Token received:
    - Access Token: eyJraWQiOiJkZWZhdWx0...
    - Token Type: Bearer
    - Expires In: 3599 seconds
    - Scope: api:read api:write
```

## 再現手順

### 1. テスト環境のセットアップ

```bash
# リポジトリをクローン
git clone <repository-url>
cd moonbit_oauth2

# 依存関係のインストール
moon install

# モックOAuth2サーバーの起動
docker compose up -d mock-oauth2
sleep 3
```

### 2. サーバーが正常に応答することを確認

```bash
curl -X POST http://localhost:8081/default/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=test_client&client_secret=test_secret&scope=api:read%20api:write"
```

**期待される結果:**
```json
{
  "token_type" : "Bearer",
  "access_token" : "eyJ...",
  "expires_in" : 3599,
  "scope" : "api:read api:write"
}
```

### 3. nativeターゲットで実行（問題の再現）

```bash
moon run --target native lib/integration_test_cli
```

**実際の結果:** レスポンスボディが空（0バイト）

### 4. jsターゲットで実行（正常動作）

```bash
moon run --target js lib/integration_test_cli
```

**実際の結果:** レスポンスボディが正常に取得される（781バイト）

### 5. クリーンアップ

```bash
docker compose down
```

## 関連コード

### 問題が発生するコード（lib/oauth2/http_client.mbt）

```moonbit
pub async fn OAuth2HttpClient::post(
  _self : OAuth2HttpClient,
  url : String,
  headers : HttpHeaders,
  body : String,
) -> Result[HttpResponse, OAuth2Error] {
  // Convert headers to mizchi/x format
  let http_headers = convert_headers(headers)

  // Send POST request using mizchi/x
  let (response, response_body) = @http.post(url, body, headers=http_headers) catch {
    err => return Err(HttpError("HTTP request failed: \{err}"))
  }

  // Convert response to our HttpResponse type
  let response_headers : HttpHeaders = {}
  response.headers.each(fn(key, value) { response_headers[key] = value })

  // ここで問題が発生
  let body_text = response_body.text()  // nativeターゲットでは空文字列を返す

  Ok(HttpResponse::new(response.code, response_headers, body_text))
}
```

### パッケージ設定（lib/oauth2/moon.pkg）

```moonbit
import {
  "mizchi/x/http",
  "moonbitlang/core/random",
  "moonbitlang/async/io",
}
```

### モジュール依存関係（moon.mod.json）

```json
{
  "name": "ryota0624/oauth2",
  "version": "0.1.0",
  "preferred-target": "native",
  "deps": {
    "mizchi/x": "0.1.3",
    "moonbitlang/async": "0.16.6"
  }
}
```

## 試行した解決策

### 1. `.text()` メソッドの使用

```moonbit
let body_text = response_body.text()
```

**結果:** nativeターゲットで空文字列、jsターゲットで正常

### 2. `.to_string()` メソッドの使用

```moonbit
let body_text = @io.Data::to_string(response_body)
```

**結果:** コンパイルエラー
```
Error: Cannot use method to_string of abstract trait @moonbitlang/async/io.Data
```

### 3. `.bytes()` メソッドの使用

```moonbit
let body_bytes = response_body.bytes()
let body_text = String::from_bytes(body_bytes)
```

**結果:** コンパイルエラー
```
Error: Cannot use method bytes of abstract trait @moonbitlang/async/io.Data
```

## 分析

### 推測される原因

1. **ターゲット固有の実装の違い**
   - mizchi/xのnativeターゲット実装とjsターゲット実装で`response_body.text()`の動作が異なる
   - nativeターゲットでは`Data`トレイトの実装に問題がある可能性

2. **非同期処理の問題**
   - nativeターゲットでレスポンスボディの読み取りが完了する前に`.text()`が呼ばれている可能性
   - jsターゲットでは正常に同期化されている

3. **バッファリングの問題**
   - nativeターゲットでレスポンスボディがバッファリングされていない
   - jsターゲットでは自動的にバッファリングされている

### 証拠

- HTTPリクエスト自体は成功している（ステータスコード200）
- サーバーは正常にレスポンスを返している（curlで確認済み）
- jsターゲットでは同じコードが正常に動作する
- リクエストボディは正しく送信されている（108バイト）

## 回避策

### 現在有効な回避策: jsターゲットを使用

```bash
# CLIツールをjsターゲットで実行
moon run --target js lib/integration_test_cli

# または、スクリプトを修正
# scripts/run_integration_test_cli.sh の34行目を以下に変更:
moon run --target js lib/integration_test_cli
```

**利点:**
- 即座に使用可能
- 完全に動作する
- コード変更不要

**欠点:**
- Node.js環境が必要
- パフォーマンスがnativeと異なる可能性

### 代替案1: 別のHTTPライブラリを使用

MoonBit標準ライブラリや他のサードパーティライブラリを調査して、nativeターゲットで正常に動作するものを探す。

### 代替案2: mizchi/xの問題が修正されるまで待つ

mizchi/xのメンテナに問題を報告し、修正を待つ。

## 次のアクション

### 短期的（即座に実施可能）

1. [x] jsターゲットで動作することを確認
2. [x] 問題を詳細にドキュメント化
3. [ ] スクリプトをjsターゲット用に更新（オプション）

### 中期的（推奨）

1. [ ] mizchi/xのGitHubリポジトリでissueを検索
   - 既存の類似問題がないか確認
2. [ ] 新規issueを作成
   - このドキュメントの内容を含める
   - 再現手順を明確に記載
3. [ ] 代替HTTPライブラリの調査
   - MoonBit公式HTTPクライアント
   - 他のコミュニティライブラリ

### 長期的

1. [ ] mizchi/xの修正を追跡
2. [ ] 修正がリリースされたらnativeターゲットに戻す
3. [ ] パフォーマンステストを実施（native vs js）

## 参考情報

### 関連ファイル

- `lib/oauth2/http_client.mbt` - HTTP通信の実装
- `lib/integration_test_cli/main.mbt` - テストCLIツール
- `scripts/run_integration_test_cli.sh` - 実行スクリプト
- `docs/completed/20260215_cli_integration_test_implementation.md` - 実装完了報告

### 外部リソース

- [mizchi/x GitHub](https://github.com/mizchi/x)
- [MoonBit Documentation](https://docs.moonbitlang.com)
- [mock-oauth2-server](https://github.com/navikt/mock-oauth2-server)

## mizchi/x issue報告用テンプレート

```markdown
## Environment
- MoonBit version: [output of `moon --version`]
- OS: macOS (Darwin 23.6.0)
- mizchi/x version: 0.1.3
- Target: native

## Issue Description
`response_body.text()` returns empty string on native target, but works correctly on js target.

## Minimal Reproduction
[Include code from this document]

## Expected Behavior
Response body should be read successfully on both native and js targets.

## Actual Behavior
- **native target**: `response_body.text()` returns empty string (0 bytes)
- **js target**: `response_body.text()` returns correct content (781 bytes)

## Workaround
Using js target instead of native target works correctly.
```

## ステータス

- **発見日**: 2026-02-15
- **最終更新**: 2026-02-15
- **状態**: 未解決 (jsターゲットで回避可能)
- **優先度**: 中（回避策あり）
- **影響範囲**: mizchi/xを使用するnativeターゲットのHTTPクライアント実装
