# Steering: モックOAuth2サーバーを使った統合テスト

## 目的・背景

OAuth2クライアントライブラリの動作を実際のHTTP通信を含めて検証するため、モックOAuth2サーバーを使った統合テストを実装する。

現在の単体テストでは：
- 個々の関数やコンポーネントの動作は検証済み
- 実際のHTTPリクエスト/レスポンスの処理は未検証
- エンドツーエンドのフローは検証されていない

## ゴール

- Docker Composeを使ったモックOAuth2サーバーのセットアップ
- 実際のHTTP通信を含む統合テストの実装
- Authorization Code Flow（PKCE含む）の完全な動作検証

## アプローチ

### 1. モックOAuth2サーバーの選定

以下のオプションを検討：

**Option A: oauth2-mock-server**
- Node.js製のシンプルなモックサーバー
- Docker imageが利用可能
- Authorization Code Flow、Client Credentials対応

**Option B: Keycloak**
- 本格的なOAuth2/OpenID Connect実装
- 重量級だが本番環境に近い動作
- Docker imageが利用可能

**Option C: Hydra**
- Ory製のOAuth2サーバー
- 軽量で高性能
- Docker imageが利用可能

**選択**: oauth2-mock-serverを採用
- 理由: テスト目的に最適、軽量、セットアップが簡単

### 2. Docker Compose構成

```yaml
version: '3.8'
services:
  oauth2-mock:
    image: ghcr.io/navikt/mock-oauth2-server:latest
    ports:
      - "8080:8080"
    environment:
      - JSON_CONFIG={...}
```

### 3. 統合テストの実装

MoonBitでの統合テストの課題：
- 現在のテストフレームワークは非同期テストに対応していない可能性
- Docker Composeの起動/停止をテストから制御する必要がある

**アプローチ**:
1. **手動起動方式**: docker-composeを手動で起動し、テストを実行
2. **スクリプト方式**: シェルスクリプトでdocker-composeの起動/停止を自動化
3. **MoonBitテスト外**: 別のテストファイル（例: `tests/integration_test.sh`）

今回は**スクリプト方式**を採用。

### 4. テスト内容

#### 4.1 Authorization Code Flow（基本）
1. Authorization URLの生成
2. （手動/自動）ブラウザでの認可
3. Authorization codeの取得
4. Token exchangeリクエスト
5. Access tokenの検証

#### 4.2 PKCE対応フロー
1. Code verifierの生成
2. Code challengeの計算
3. Authorization URL生成（PKCE付き）
4. Token exchangeリクエスト（code_verifier付き）
5. Access tokenの検証

#### 4.3 エラーハンドリング
1. 無効なcodeでのtoken exchange
2. 無効なclient_secretでのリクエスト
3. エラーレスポンスのパース

### 5. テストスクリプトの構成

```bash
#!/bin/bash
# tests/run_integration_tests.sh

# Start mock server
docker-compose up -d

# Wait for server to be ready
sleep 2

# Run MoonBit integration tests
moon test --package oauth2_integration

# Stop mock server
docker-compose down
```

## スコープ

### 含む
- docker-compose.ymlの作成
- モックOAuth2サーバーのセットアップ
- Authorization Code Flowの統合テスト
- PKCEフローの統合テスト
- エラーハンドリングのテスト
- テスト実行スクリプト

### 含まない
- Client Credentials Flowのテスト（Step 5で実装予定）
- Password Flowのテスト（Step 5で実装予定）
- リフレッシュトークンのテスト（将来の拡張）
- 本番環境でのテスト（モック環境のみ）

## 影響範囲

### 新規ファイル
- `docker-compose.yml`: モックサーバー設定
- `tests/integration/`: 統合テスト用ディレクトリ
- `tests/integration/auth_code_flow_test.mbt`: Authorization Code Flowテスト
- `tests/integration/pkce_flow_test.mbt`: PKCEフローテスト
- `tests/run_integration_tests.sh`: テスト実行スクリプト

### 変更ファイル
- `README.md`: 統合テストの実行方法を追加
- `Todo.md`: 進捗を更新

## 技術的課題

### 課題1: 非同期テストの実行
MoonBitのテストフレームワークが非同期関数をサポートしているか不明。

**解決策**:
- 非同期関数をテスト内で`await`して同期的に実行
- または、テストを非同期対応にする

### 課題2: HTTPサーバーの起動待ち
Docker Composeでサーバーを起動後、リクエストを受け付けるまでに時間がかかる。

**解決策**:
- `sleep`で待機
- または、ヘルスチェックエンドポイントをポーリング

### 課題3: 認可コードの取得
Authorization Code Flowでは、ブラウザでの認可が必要。

**解決策**:
- モックサーバーの自動承認機能を使用
- または、テスト用のエンドポイントで直接codeを取得

## 実装順序

1. **Step 6.1**: docker-compose.ymlの作成とモックサーバーの起動確認
2. **Step 6.2**: 基本的な統合テストの実装（Authorization Code Flow）
3. **Step 6.3**: PKCEフローの統合テスト
4. **Step 6.4**: エラーハンドリングのテスト
5. **Step 6.5**: テスト実行スクリプトの作成
6. **Step 6.6**: ドキュメント整備

## 参考資料

- [mock-oauth2-server](https://github.com/navikt/mock-oauth2-server)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)

## 成功基準

- [ ] モックOAuth2サーバーがDocker Composeで起動できる
- [ ] Authorization Code Flowの完全なフローが動作する
- [ ] PKCEフローが正しく動作する
- [ ] エラーレスポンスが正しく処理される
- [ ] 統合テストが自動化されている
- [ ] ドキュメントに統合テストの実行方法が記載されている
