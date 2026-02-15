# OAuth2統合テストガイド

## 概要

このドキュメントでは、OAuth2クライアントライブラリの統合テストの実行方法を説明します。

## 統合テストの種類

### 1. リクエスト構造テスト（自動）
- **場所**: `lib/oauth2/integration_test.mbt`
- **テスト数**: 8テスト
- **内容**: リクエストボディとURLの構造を検証
- **実行**: `moon test`

### 2. 実際のHTTP通信テスト（CLI）
- **場所**: `cmd/integration_test/main.mbt`
- **内容**: mock-oauth2-serverとの実際の通信を検証
- **実行**: `./scripts/run_integration_test_cli.sh`

## 前提条件

### 必須
- Docker & Docker Compose
- MoonBit CLI (`moon`)
- curl（サーバー準備確認用）

### 環境
- ポート8081が利用可能であること
- インターネット接続（Dockerイメージダウンロード用）

## 統合テストの実行方法

### 方法1: 全テスト実行（推奨）

```bash
./scripts/run_integration_tests.sh
```

**動作**:
1. mock-oauth2-serverを起動
2. サーバーの準備を待機（最大30秒）
3. 全テスト（132テスト）を実行
4. サーバーを停止

**出力例**:
```
🚀 Starting mock OAuth2 server...
⏳ Waiting for server to be ready...
✅ Mock OAuth2 server is ready!

🧪 Running integration tests...
Total tests: 132, passed: 132, failed: 0.

✅ All tests passed!
🧹 Stopping mock OAuth2 server...
```

### 方法2: CLI統合テスト実行

```bash
./scripts/run_integration_test_cli.sh
```

**動作**:
1. mock-oauth2-serverを起動
2. サーバーの準備を待機
3. CLIツールで実際のHTTP通信テストを実行
4. サーバーを停止

**出力例**:
```
🧪 OAuth2 Integration Test Tool
==================================================

📋 Test 1: Client Credentials Grant
--------------------------------------------------
  Token URL: http://localhost:8081/default/token
  Client ID: test_client
  Scopes: api:read, api:write

  Sending request...
  ✅ Success! Token received:
    - Access Token: eyJraWQiOiJkZWZhdWx0...
    - Token Type: Bearer
    - Expires In: 3600 seconds
    - Scope: api:read api:write
```

### 方法3: 手動テスト

#### Step 1: サーバー起動
```bash
docker compose up -d mock-oauth2
```

#### Step 2: サーバー確認
```bash
curl http://localhost:8081/default/.well-known/openid-configuration
```

#### Step 3: テスト実行
```bash
# リクエスト構造テスト
moon test

# CLI統合テスト
moon run cmd/integration_test
```

#### Step 4: サーバー停止
```bash
docker compose down
```

## テスト対象

### Authorization Code Flow
- ✅ 認可URL生成の検証
- ✅ トークンリクエストボディの検証
- ✅ PKCEパラメータの検証

### Client Credentials Grant
- ✅ リクエストボディの検証（スコープあり）
- ✅ リクエストボディの検証（スコープなし）
- ✅ 実際のHTTP通信（CLIツール）

### Password Credentials Grant
- ✅ リクエストボディの検証（client_secretあり）
- ✅ リクエストボディの検証（client_secretなし）

## mock-oauth2-serverについて

### 概要
- **イメージ**: `ghcr.io/navikt/mock-oauth2-server:2.1.10`
- **ポート**: 8081（ホスト） → 8080（コンテナ）
- **エンドポイント**: `/default/*`

### 主要エンドポイント
- **認可**: `http://localhost:8081/default/authorize`
- **トークン**: `http://localhost:8081/default/token`
- **OpenID設定**: `http://localhost:8081/default/.well-known/openid-configuration`

### 特徴
- 自動的にトークンを発行
- 任意のclient_id/client_secretを受け入れ
- PKCEサポート
- 全てのgrant_typeをサポート

### デバッグ
```bash
# ログ確認
docker compose logs mock-oauth2

# コンテナ状態確認
docker compose ps

# コンテナ内に入る
docker compose exec mock-oauth2 sh
```

## トラブルシューティング

### ポート8081が既に使用されている
```bash
# 使用中のプロセスを確認
lsof -i :8081

# Docker Composeのポート変更
# docker-compose.ymlの ports を変更
ports:
  - "8082:8080"  # 8082に変更
```

### サーバーが起動しない
```bash
# Dockerイメージを再取得
docker compose pull mock-oauth2

# コンテナをクリーンアップ
docker compose down -v
docker compose up -d mock-oauth2
```

### テストがタイムアウトする
```bash
# サーバーが完全に起動するまで待つ
sleep 10
moon test
```

### 非同期テストの制限
MoonBitのテストフレームワークは現在、非同期テストを完全にサポートしていない可能性があります。そのため：

- **リクエスト構造テスト**: 同期的に実行可能
- **実際のHTTP通信テスト**: CLIツールで実行

## テストの追加方法

### リクエスト構造テストの追加

`lib/oauth2/integration_test.mbt`に追加：

```moonbit
test "integration: my new test" {
  // テストコード
  let request = // ... リクエスト作成
  let body = request.build_request_body()
  assert_true(body.contains("expected_value"))
}
```

### CLIテストの追加

`cmd/integration_test/main.mbt`に追加：

```moonbit
fn test_my_feature() -> Unit {
  println("\n📋 Test: My Feature")
  println("-" * 50)

  // テストロジック
  let result = // ... 実行

  match result {
    Ok(value) => println("  ✅ Success!")
    Err(error) => println("  ❌ Error: \{error}")
  }
}

// init関数に追加
fn init {
  // ...
  test_my_feature()
}
```

## ベストプラクティス

### テスト実行前
1. Dockerが起動していることを確認
2. ポート8081が利用可能であることを確認
3. 最新のコードをビルド: `moon check`

### テスト実行後
1. サーバーを停止: `docker compose down`
2. 不要なコンテナを削除: `docker compose down -v`

### CI/CD
GitHub Actionsなどで自動実行する場合：

```yaml
- name: Start mock OAuth2 server
  run: docker compose up -d mock-oauth2

- name: Wait for server
  run: sleep 5

- name: Run integration tests
  run: moon test

- name: Stop mock OAuth2 server
  run: docker compose down
```

## 参考資料

- [mock-oauth2-server GitHub](https://github.com/navikt/mock-oauth2-server)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
