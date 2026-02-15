# Steering: HTTPクライアント統合

## 目的・背景

OAuth2クライアントライブラリにHTTPクライアント機能を統合する。当初の計画では独自のHTTPクライアント抽象化層を実装する予定だったが、`mizchi/x`ライブラリを使用することで、Native/JSの差異を意識することなく統一されたHTTPクライアントAPIを利用できる。

### なぜ必要か
- OAuth2フローではトークンエンドポイントへのHTTPリクエストが必須
- Native/JS両環境で動作する必要がある
- mizchi/xを使用することで、プラットフォーム固有の実装を避けられる

## ゴール

### 作業完了時の状態
1. mizchi/xライブラリが依存関係として追加されている
2. OAuth2トークンリクエスト用のHTTPクライアント機能が実装されている
3. HTTPリクエスト/レスポンスのラッパー型が定義されている
4. エラーハンドリングが適切に実装されている
5. HTTPクライアントの基本的なテストが完成している

### 成功の基準
- 実際のHTTPエンドポイント（例：httpbin.org）に対してリクエストが成功する
- Native/JSの両環境でテストが通る
- OAuth2のトークンリクエストに必要な機能が揃っている

## アプローチ

### 技術的アプローチ
1. **依存関係の追加**: moon.mod.jsonにmizchi/xを追加
2. **HTTPクライアントラッパー**: mizchi/xのHTTP APIをOAuth2用にラップ
3. **型安全性**: リクエスト/レスポンスを型安全に扱う
4. **エラーマッピング**: HTTPエラーをOAuth2Errorにマッピング

### 使用するmizchi/x API
- `http::post`: トークンエンドポイントへのPOSTリクエスト
- 必要に応じて`http::get`: ディスカバリエンドポイント用

## スコープ

### 含むもの（Phase 1）

#### 1. 依存関係の追加
- `moon.mod.json`に`mizchi/x`を追加
- 必要なパッケージ依存の設定

#### 2. HTTPリクエスト/レスポンス型の定義
```moonbit
// HTTPリクエストのボディとヘッダー
struct HttpRequest {
  url: String
  method: String
  headers: Map[String, String]
  body: String
}

// HTTPレスポンス
struct HttpResponse {
  status_code: Int
  headers: Map[String, String]
  body: String
}
```

#### 3. HTTPクライアント実装
- OAuth2トークンリクエスト用のHTTP POST機能
- Content-Type: application/x-www-form-urlencodedのサポート
- Authorization ヘッダーの設定（Basic認証）
- レスポンスのJSONパース準備

#### 4. エラーハンドリング
- HTTPステータスコードのチェック
- ネットワークエラーのハンドリング
- エラーレスポンスのパース（OAuth2エラー形式）

#### 5. テスト
- httpbin.orgを使った実際のHTTPリクエストテスト
- エラーハンドリングのテスト
- ヘッダー設定のテスト

### 含まないもの（後で実装）
- HTTPリトライロジック
- タイムアウト設定の詳細な制御
- HTTPキャッシング
- プロキシサポート
- リダイレクトの自動追跡（OAuth2ではリダイレクトを追跡しないことが推奨）

### 技術的制約
- mizchi/xの現在のAPI仕様に従う
- 非同期処理は必要に応じて対応
- moonbitlang/asyncへの依存

## 影響範囲

### 新規作成ファイル
```
lib/oauth2/
├── http_client.mbt       # HTTPクライアント実装
├── http_types.mbt        # HTTPリクエスト/レスポンス型
└── http_client_wbtest.mbt # HTTPクライアントテスト
```

### 変更ファイル
- `moon.mod.json`: mizchi/x依存追加
- `lib/oauth2/moon.pkg`: 依存パッケージの追加
- `lib/oauth2/error.mbt`: HTTP関連エラーの使用開始

## 実装計画

### Step 2.1: 依存関係の追加とセットアップ（30分）
- moon.mod.jsonへのmizchi/x追加
- moon.pkgの更新
- 依存関係の動作確認

### Step 2.2: HTTP型定義（1時間）
- HttpRequest/HttpResponse型の定義
- ヘッダー、ボディのハンドリング
- URL、メソッド等の基本型

### Step 2.3: HTTPクライアント実装（2-3時間）
- mizchi/x httpパッケージの使用
- POST リクエストの実装
- application/x-www-form-urlencoded のボディ構築
- Basic認証ヘッダーの構築

### Step 2.4: エラーハンドリング（1-2時間）
- HTTPステータスコードチェック
- OAuth2エラーレスポンスのパース
- HttpError, ParseErrorの活用

### Step 2.5: テストとドキュメント（1-2時間）
- httpbin.orgを使った統合テスト
- エラーケースのテスト
- 使用例のドキュメント

## リスクと対策

### リスク1: mizchi/xの学習コスト
- **対策**: 公式のサンプルコードを参照し、シンプルな例から始める

### リスク2: 非同期処理の複雑さ
- **対策**: 必要最小限の非同期機能から実装し、段階的に拡張

### リスク3: mizchi/xのバグや制限
- **対策**: 問題が見つかった場合は、issueを報告するか、ワークアラウンドを検討

## 参考資料
- [mizchi/x GitHub Repository](https://github.com/mizchi/x)
- [moonbitlang/async](https://github.com/moonbitlang/async)
- [RFC 6749: OAuth 2.0 - Token Endpoint](https://datatracker.ietf.org/doc/html/rfc6749#section-3.2)
- [httpbin.org](https://httpbin.org) - HTTPテスト用サービス

## 次のステップ
1. このsteeringドキュメントのレビューと承認
2. mizchi/xの依存関係追加
3. HTTP型定義の実装開始
