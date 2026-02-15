# 完了報告: Native ターゲットでのレスポンスボディ取得バグ修正

## 実装内容

mizchi/x および moonbitlang/async の HTTP クライアントにおいて、native ターゲットで外部サーバーからのレスポンスボディが空になる問題を調査・修正しました。

### 主な変更点

1. **根本原因の特定**
   - `async/src/http/parser.mbt`の`Reader::read_response()`関数が、Content-Length や Transfer-Encoding ヘッダーがない場合に`self.body`を適切に初期化していなかった
   - HTTP/1.1 仕様では、これらのヘッダーがない場合、接続切断までボディを読み取る必要がある

2. **修正内容**
   - `Reader::read_response()`に、ヘッダーがない場合のフォールバック処理を追加
   - Content-Length も Transfer-Encoding もない場合、`self.body = PassThrough`に設定
   - PassThrough モードは接続切断(EOF)まで読み取りを継続する

3. **テストの追加**
   - `/Users/ryota.suzuki/git/async/src/http/external_server_test.mbt`: httpbin.org を使用した外部サーバーテスト(3件)
   - `/Users/ryota.suzuki/git/x/src/http/external_docker_test.mbt`: Docker mock-oauth2-server を使用した再現テスト(1件)

## 技術的な決定事項

### PassThrough モードの採用理由

HTTP/1.1 仕様では、レスポンスボディの長さを決定する方法は以下の優先順位:

1. **Transfer-Encoding: chunked** - チャンク形式で読み取り(`Chunked`モード)
2. **Content-Length ヘッダー** - 固定長で読み取り(`Fixed`モード)
3. **上記がない場合** - 接続切断まで読み取り(`PassThrough`モード)

mock-oauth2-server は`Connection: close`ヘッダーのみを送信し、Content-Length を提供しないため、PassThrough モードが必要でした。

### リクエストボディの処理

HTTP リクエストの場合、仕様上 POST/PUT/PATCH は Content-Length または Transfer-Encoding を必須とするため、PassThrough は適用せず、Empty のままにしました。これにより、`enter_passthrough_mode()`後の残データ読み取りが正常に動作します。

## 変更ファイル一覧

### 追加

- `/Users/ryota.suzuki/git/async/src/http/external_server_test.mbt`
  - httpbin.org を使用した外部サーバー接続テスト
  - GET, POST, chunked encoding のテストケース

- `/Users/ryota.suzuki/git/x/src/http/external_docker_test.mbt`
  - Docker mock-oauth2-server を使用した OAuth2 トークン取得テスト
  - 実際の OAuth2 プロジェクトのシナリオを再現

- `/Users/ryota.suzuki/git/x/docs/investigation_native_response_body_bug.md`
  - 詳細な調査ドキュメント

### 変更

- `/Users/ryota.suzuki/git/async/src/http/parser.mbt`
  - `Reader::read_response()`: PassThrough フォールバック処理を追加(line 238-253)
  - コメント追加で仕様を明確化

- `/Users/ryota.suzuki/git/x/moon.mod.json`
  - 依存関係を`moonbitlang/async@0.16.6`から`{ "path": "../async" }`に変更
  - ローカルの修正版 async を使用するため

## テスト

### 実施したテスト

1. **async リポジトリ**: 全 406 テスト - 全てパス
2. **x リポジトリ**: Docker mock-oauth2-server テスト - パス
3. **httpbin.org 外部サーバーテスト**: 3 件全てパス
   - GET リクエスト(Content-Length あり)
   - POST リクエスト(Content-Length あり)
   - Chunked encoding レスポンス

### テストカバレッジ

- ✅ Content-Length ヘッダーありのレスポンス
- ✅ Transfer-Encoding: chunked のレスポンス
- ✅ ヘッダーなし + Connection: close のレスポンス(PassThrough)
- ✅ GET リクエストの残データ読み取り(passthrough mode)
- ✅ サーバー接続テスト(proxy, WebSocket など)

### 動作確認方法

```bash
# Docker コンテナ起動
cd /Users/ryota.suzuki/git/moonbit_oauth2
docker compose up -d mock-oauth2

# async リポジトリのテスト
cd /Users/ryota.suzuki/git/async
moon test src/http/external_server_test.mbt

# x リポジトリのテスト
cd /Users/ryota.suzuki/git/x
moon test src/http/external_docker_test.mbt

# 全テスト実行
moon test
```

## デバッグプロセス

### 調査手順

1. **問題の再現**
   - x リポジトリのコードで外部サーバーからのレスポンスが空になることを確認

2. **デバッグログ追加**
   - `read_headers()`にデバッグ出力を追加
   - 受信したヘッダー行を全て出力

3. **curl との比較**
   - curl で同じリクエストを実行し、レスポンスヘッダーを確認
   - mock-oauth2-server が Content-Length を送信していないことを発見

4. **HTTP/1.1 仕様の確認**
   - Content-Length/Transfer-Encoding がない場合の動作を確認
   - PassThrough モードが適切な解決策であることを確認

5. **修正と検証**
   - PassThrough フォールバックを実装
   - 全テストが通ることを確認

### 発見した事実

- httpbin.org は常に Content-Length ヘッダーを送信する
- mock-oauth2-server は Content-Length を送信せず、Connection: close のみ
- 既存の`read_headers()`はヘッダー内で`self.body`を設定していた
- しかし、ヘッダーがない場合のフォールバックが`read_response()`になかった

## 今後の課題・改善点

### 完了済み

- ✅ 外部サーバーからのレスポンスボディ取得
- ✅ Content-Length なしのレスポンス対応
- ✅ 包括的なテストカバレッジ

### 今後の検討事項

- [ ] **upstream への貢献**: moonbitlang/async にこの修正を PR として提出
- [ ] **ステータスコード対応**: 1xx, 204, 304 レスポンスはボディなしとして処理すべき
- [ ] **HEAD メソッド対応**: HEAD レスポンスは Content-Length があってもボディなし
- [ ] **HTTP/1.0 対応**: HTTP/1.0 では Connection ヘッダーの扱いが異なる
- [ ] **タイムアウト処理**: PassThrough モードで接続が切断されない場合のタイムアウト

## 参考資料

### HTTP/1.1 仕様
- [RFC 7230 Section 3.3.3: Message Body Length](https://datatracker.ietf.org/doc/html/rfc7230#section-3.3.3)
  - レスポンスボディの長さ決定アルゴリズムを定義

### 関連 Issue
- moonbitlang/async: HTTP クライアントのレスポンスボディ取得に関する問題

### テストサーバー
- [httpbin.org](https://httpbin.org): HTTP リクエスト/レスポンステスト用公開 API
- [mock-oauth2-server](https://github.com/navikt/mock-oauth2-server): OAuth2 モックサーバー

## 結論

HTTP/1.1 仕様に準拠し、Content-Length や Transfer-Encoding ヘッダーがないレスポンスにも対応できるようになりました。これにより、moonbit_oauth2 プロジェクトで使用している mock-oauth2-server からの OAuth2 トークン取得が正常に動作するようになります。

修正は async リポジトリの1ファイル(parser.mbt)への小さな変更で、既存の全テスト(406件)が引き続きパスすることを確認しました。
