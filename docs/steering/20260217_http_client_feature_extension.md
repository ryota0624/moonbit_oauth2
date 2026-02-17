# Steering: HTTPクライアント機能拡張

## 目的・背景

現在のOAuth2HttpClientは基本的なHTTP通信機能のみを提供しており、本番環境で使用する上で以下の課題があります：

1. **タイムアウトの未設定**: mizchi/xのデフォルトタイムアウトに依存しており、長時間ハングする可能性がある
2. **リトライ機能の欠如**: 一時的なネットワークエラーや5xxエラーに対して自動リトライができない
3. **設定の柔軟性不足**: カスタムヘッダー、User-Agent等の設定ができない

本番環境での信頼性と可用性を高めるため、これらの機能を実装します。

## ゴール

OAuth2HttpClientに以下の機能を追加し、本番環境で使用可能な堅牢なHTTPクライアントを実現する：

1. **タイムアウト設定**
   - リクエストごとのタイムアウト設定（デフォルト: 30秒）
   - カスタマイズ可能

2. **リトライロジック**
   - 一時的なネットワークエラーの自動リトライ
   - 指数バックオフ戦略の実装
   - リトライ回数の設定（デフォルト: 3回）
   - リトライ対象エラーの選択（5xx、タイムアウト等）

3. **HTTPクライアント設定の拡充**
   - timeout: Int? - タイムアウト設定（ミリ秒）
   - max_retries: Int? - 最大リトライ回数
   - custom_headers: HttpHeaders? - 全リクエストに追加するカスタムヘッダー
   - user_agent: String? - User-Agentヘッダー
   - OAuth2HttpClient::new_with_config()コンストラクタの追加

## アプローチ

### 1. OAuth2HttpClientConfig構造体の導入

設定を管理する専用の構造体を作成：

```moonbit
pub struct OAuth2HttpClientConfig {
  timeout_ms : Int        // タイムアウト（ミリ秒、デフォルト: 30000）
  max_retries : Int       // 最大リトライ回数（デフォルト: 3）
  custom_headers : HttpHeaders?  // カスタムヘッダー
  user_agent : String?    // User-Agent
  debug : Bool            // デバッグ出力（デフォルト: false）
}
```

### 2. OAuth2HttpClient構造体の更新

現在の`debug: Bool`フィールドを`config: OAuth2HttpClientConfig`に置き換え：

```moonbit
pub struct OAuth2HttpClient {
  config : OAuth2HttpClientConfig
}
```

### 3. コンストラクタの追加

- `OAuth2HttpClient::new()` - デフォルト設定で作成（既存の挙動維持）
- `OAuth2HttpClient::new_with_config(config)` - カスタム設定で作成
- `OAuth2HttpClient::new_with_debug(debug)` - デバッグ設定のみ変更（後方互換性維持）
- `OAuth2HttpClientConfig::default()` - デフォルト設定作成
- `OAuth2HttpClientConfig::builder()` - Builderパターンでの設定作成

### 4. タイムアウト実装

mizchi/xのタイムアウト機能を調査し、以下のいずれかで実装：
- Option A: mizchi/xがタイムアウト機能を提供している場合はそれを使用
- Option B: MoonBitのタイマー機能を使用してタイムアウトを実装
- Option C: 外部ライブラリの調査

### 5. リトライロジック実装

指数バックオフアルゴリズムを実装：

```moonbit
// リトライ間隔: base_delay * (2 ^ retry_count)
// 例: 1秒 -> 2秒 -> 4秒 -> 8秒
fn calculate_backoff(retry_count : Int, base_delay_ms : Int) -> Int {
  base_delay_ms * (1 << retry_count)  // bit shift for 2^n
}
```

リトライ対象エラー：
- HTTPステータスコード: 5xx (500-599)
- ネットワークエラー: タイムアウト、接続エラー
- リトライ不可: 4xx (クライアントエラー)

### 6. HTTPクライアントメソッドの更新

`post()`と`get()`メソッドにリトライロジックを追加：

```moonbit
async fn OAuth2HttpClient::post_with_retry(
  self : OAuth2HttpClient,
  url : String,
  headers : HttpHeaders,
  body : String,
) -> Result[HttpResponse, OAuth2Error] {
  let mut retry_count = 0
  loop {
    match self.post_internal(url, headers, body).await {
      Ok(response) => {
        if response.status_code >= 500 && retry_count < self.config.max_retries {
          // Retry for 5xx errors
          let backoff_ms = calculate_backoff(retry_count, 1000)
          sleep(backoff_ms).await
          retry_count = retry_count + 1
          continue
        }
        return Ok(response)
      }
      Err(err) => {
        if is_retryable_error(err) && retry_count < self.config.max_retries {
          // Retry for network errors
          let backoff_ms = calculate_backoff(retry_count, 1000)
          sleep(backoff_ms).await
          retry_count = retry_count + 1
          continue
        }
        return Err(err)
      }
    }
  }
}
```

## スコープ

### 含む

1. **OAuth2HttpClientConfig構造体**
   - timeout_ms、max_retries、custom_headers、user_agent、debugフィールド
   - default()、builder()メソッド

2. **OAuth2HttpClient構造体の更新**
   - config: OAuth2HttpClientConfigフィールド
   - new()、new_with_config()、new_with_debug()コンストラクタ

3. **タイムアウト機能**
   - リクエストタイムアウトの実装
   - デフォルト30秒、カスタマイズ可能

4. **リトライロジック**
   - 指数バックオフアルゴリズム
   - リトライ対象エラーの判定（5xx、タイムアウト等）
   - リトライ回数の制御（デフォルト3回）

5. **カスタムヘッダー機能**
   - custom_headers、user_agentの設定
   - 全リクエストへの自動追加

6. **テスト**
   - OAuth2HttpClientConfigのユニットテスト（10テスト）
   - タイムアウトのテスト（5テスト）
   - リトライロジックのテスト（10テスト）
   - カスタムヘッダーのテスト（5テスト）

### 含まない

1. **HTTPメソッドの追加**
   - PUT、PATCH、DELETEメソッドは今回のスコープ外
   - 必要になった時点で別途実装

2. **接続プールの実装**
   - 接続の再利用やプーリングは今回のスコープ外
   - mizchi/xの機能に依存

3. **HTTPSクライアント証明書認証**
   - mTLS（RFC 8705）は今回のスコープ外
   - Phase 2の拡張機能として実装

4. **詳細なメトリクス収集**
   - リクエスト時間、リトライ回数等のメトリクスは今回のスコープ外
   - 将来的な改善として検討

5. **カスタムリトライ戦略**
   - 線形バックオフ、ジッター等は今回のスコープ外
   - 指数バックオフのみ実装

## 影響範囲

### 変更ファイル

1. **lib/http_client.mbt**（大きな変更）
   - OAuth2HttpClientConfig構造体の追加（約30行）
   - OAuth2HttpClient構造体の更新（configフィールド）
   - コンストラクタの追加・更新（約20行）
   - post()、get()メソッドにリトライロジック追加（約50行）
   - ヘルパー関数追加（calculate_backoff、is_retryable_error等、約30行）

2. **lib/http_client_wbtest.mbt**（新規テスト追加）
   - OAuth2HttpClientConfigのテスト（約50行）
   - タイムアウトのテスト（約30行）
   - リトライロジックのテスト（約60行）
   - カスタムヘッダーのテスト（約30行）

3. **lib/moon.pkg**（依存関係の確認）
   - 既存の依存関係で十分か確認
   - 必要に応じて追加

### 影響を受けるコンポーネント

1. **OAuth2HttpClientを使用する全モジュール**
   - authorization_request.mbt
   - token_request.mbt
   - client_credentials_request.mbt
   - password_request.mbt
   - OIDC関連のリクエスト
   - **影響**: コンストラクタの呼び出しは変更不要（new()の挙動は維持）
   - **推奨**: 本番環境ではnew_with_config()を使用するよう推奨

2. **統合テスト**
   - cmd/integration_test/main.mbt
   - **影響**: タイムアウト、リトライの挙動を確認
   - **対応**: テストケースの追加（タイムアウト、リトライ）

3. **サンプルアプリケーション**
   - examples/google/
   - **影響**: 本番環境での使用例を更新
   - **対応**: new_with_config()の使用例を追加

### 後方互換性

- `OAuth2HttpClient::new()` - デフォルト設定で作成（既存の挙動維持）
- `OAuth2HttpClient::new_with_debug(debug)` - 既存のAPIを維持
- **破壊的変更なし**: 既存のコードはそのまま動作

## 実装順序

### Step 1: OAuth2HttpClientConfig構造体の実装（30分）
- 構造体定義
- default()、builder()メソッド
- ユニットテスト

### Step 2: OAuth2HttpClient構造体の更新（30分）
- configフィールドへの置き換え
- コンストラクタの更新
- 既存のpost()、get()メソッドの動作確認

### Step 3: タイムアウト機能の実装（1時間）
- mizchi/xのタイムアウト機能調査
- タイムアウト実装
- タイムアウトテスト

### Step 4: リトライロジックの実装（2時間）
- calculate_backoff関数
- is_retryable_error関数
- post()、get()メソッドへのリトライロジック追加
- リトライテスト

### Step 5: カスタムヘッダー機能の実装（30分）
- custom_headers、user_agentの適用
- カスタムヘッダーテスト

### Step 6: 統合テストの更新（30分）
- cmd/integration_test/main.mbtの更新
- サンプルアプリケーションの更新

### Step 7: ドキュメント更新（30分）
- README.mdの更新
- 完了ドキュメントの作成

**推定総工数**: 5-6時間

## 技術的な検討事項

### 1. mizchi/xのタイムアウト機能

**調査項目**:
- mizchi/xがタイムアウト機能を提供しているか
- MoonBitの非同期ランタイムでタイムアウトを実装する方法

**代替案**:
- タイムアウト機能がない場合は、MoonBitのタイマー機能を調査
- 最悪の場合、タイムアウト機能は今回のスコープから除外

### 2. MoonBitのsleep関数

**調査項目**:
- MoonBitで非同期sleep機能が利用可能か
- moonbitlang/asyncパッケージの機能

**代替案**:
- sleep機能がない場合は、リトライ間隔なしでリトライを実装

### 3. エラー型の拡張

**検討事項**:
- OAuth2Errorにリトライ情報を追加するか
  - 例: `HttpError(message, retry_count, max_retries)`
- エラーメッセージに詳細情報を含める

**決定**:
- まずはシンプルにエラーメッセージに情報を含める
- 将来的にエラー型の拡張を検討

## リスクと対策

### リスク1: mizchi/xのタイムアウト機能不足

**確率**: 中
**影響**: 高
**対策**:
- 事前にmizchi/xのドキュメントとコードを調査
- タイムアウト機能がない場合は、MoonBitの代替機能を調査
- 最悪の場合、タイムアウト機能は後回しにする

### リスク2: MoonBitの非同期sleep機能不足

**確率**: 中
**影響**: 中
**対策**:
- moonbitlang/asyncパッケージを調査
- sleep機能がない場合は、リトライ間隔なしでリトライを実装
- Issue/PRで機能追加を依頼

### リスク3: リトライロジックによるテスト実行時間の増加

**確率**: 高
**影響**: 低
**対策**:
- テスト時はリトライ回数を1回に制限
- モックサーバーで即座にエラーを返すテストケースを作成

### リスク4: 後方互換性の破壊

**確率**: 低
**影響**: 高
**対策**:
- 既存のAPIは維持（new()、new_with_debug()）
- 全既存テストが通ることを確認
- 段階的に移行できるようにする

## 成功基準

1. **機能実装**
   - [ ] OAuth2HttpClientConfig構造体の実装
   - [ ] タイムアウト機能の実装
   - [ ] リトライロジックの実装
   - [ ] カスタムヘッダー機能の実装

2. **テスト**
   - [ ] 全既存テストが成功（約120テスト）
   - [ ] 新規テスト追加（約30テスト）
   - [ ] 統合テストの更新と成功

3. **ドキュメント**
   - [ ] README.mdの更新
   - [ ] 使用例の追加
   - [ ] 完了ドキュメントの作成

4. **コード品質**
   - [ ] moon fmtでフォーマット済み
   - [ ] moon infoで公開API確認
   - [ ] moon testで全テスト成功

## 次のステップ

1. mizchi/xのタイムアウト機能を調査
2. MoonBitの非同期sleep機能を調査
3. OAuth2HttpClientConfig構造体の実装から開始
4. 段階的に機能を追加し、各ステップでテスト実行

## 参考資料

- Todo.md: Phase 1.5 HTTPクライアント機能拡張（行153-177）
- lib/http_client.mbt: 現在の実装
- lib/http_types.mbt: HTTP型定義
- https://docs.rs/reqwest - Rustの人気HTTPクライアント（リトライロジックの参考）
- RFC 7231 Section 6.6 - HTTPステータスコード（5xx）
- Exponential Backoff - リトライ戦略の標準的なアルゴリズム
