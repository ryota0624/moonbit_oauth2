# Steering: コードのリファクタリングとクリーンアップ

実施日: 2026-02-16

## 目的・背景

現在のOAuth2ライブラリは機能的には完成していますが、いくつかの箇所で独自実装が使用されており、保守性やパフォーマンスの観点から改善の余地があります。

### 改善が必要な理由

1. **標準ライブラリの活用不足**
   - SHA256、Base64、JSON処理などで独自実装を使用
   - MoonBitの標準ライブラリ（moonbitlang/x）が提供する機能を活用できていない
   - コードの重複、バグのリスク、保守コストの増加

2. **デバッグ出力の制御不足**
   - `println`によるデバッグ出力が常に表示される
   - 本番環境では不要な出力がログを汚染
   - ユーザーが制御できない

3. **コード品質の向上**
   - テストカバレッジ向上のための準備
   - 将来的な機能追加を容易にする
   - コードの可読性と保守性の向上

## ゴール

1. **標準ライブラリへの移行**
   - SHA256実装を`moonbitlang/x/crypto`に置き換え
   - Base64実装を`moonbitlang/x/codec/base64`に置き換え
   - JSON処理を適切なパッケージ使用に統一

2. **デバッグ出力の制御可能化**
   - `OAuth2HttpClient`に`debug`フィールドを追加
   - デバッグ出力をフラグで制御
   - デフォルトはデバッグ出力無効

3. **コード品質の向上**
   - ネストしたパターンマッチをguard節に置き換え（該当箇所があれば）
   - コードの可読性向上
   - テストの維持

4. **互換性の維持**
   - 外部APIは変更しない（後方互換性）
   - すべてのテストが引き続きパス
   - 動作検証の成功

## アプローチ

### Phase 1: デバッグ出力の制御可能化（優先度: 高、工数: 1時間）

#### 1.1 OAuth2HttpClientの拡張

**変更ファイル**: `lib/oauth2/http_client.mbt`

**現状**:
```moonbit
pub struct OAuth2HttpClient {
  _dummy : Unit
}
```

**改善後**:
```moonbit
pub struct OAuth2HttpClient {
  debug : Bool  // デバッグ出力フラグ
}

pub fn OAuth2HttpClient::new() -> OAuth2HttpClient {
  { debug: false }  // デフォルトはデバッグ無効
}

pub fn OAuth2HttpClient::new_with_debug(debug : Bool) -> OAuth2HttpClient {
  { debug }
}
```

#### 1.2 デバッグ出力の条件化

**変更箇所**: `post()`と`get()`メソッド内の全`println`

**改善前**:
```moonbit
println("DEBUG http_client POST:")
println("  URL: \{url}")
```

**改善後**:
```moonbit
if self.debug {
  println("DEBUG http_client POST:")
  println("  URL: \{url}")
}
```

**影響範囲**: 17箇所のprintln (line 229-304)

### Phase 2: SHA256のライブラリ化（優先度: 高、工数: 2時間）

#### 2.1 現状分析

**独自実装**: `lib/oauth2/sha256.mbt` (192行)
- SHA256アルゴリズムの完全実装
- RFC 6234準拠
- PKCE code_challenge計算に使用

**問題点**:
- コード量が多い（192行）
- テストとメンテナンスが必要
- moonbitlang/x/cryptoが同等機能を提供

#### 2.2 移行方針

**使用ライブラリ**: `moonbitlang/x/crypto`

**確認事項**:
1. `@crypto/sha256`パッケージの存在確認
2. API互換性の確認
3. パフォーマンスの確認（RFC 7636テストベクター）

**移行ステップ**:
1. `moon.pkg`に`@crypto`依存を追加（既に追加済み）
2. `sha256.mbt`の`sha256()`関数を置き換え
3. `sha256_hex()`関数を置き換え
4. `pkce.mbt`での使用箇所を確認
5. テスト実行（RFC 7636テストベクター）
6. 独自実装の削除または非推奨化

**代替案**:
- 独自実装を残す場合: `deprecated.mbt`に移動

### Phase 3: Base64URLのライブラリ化（優先度: 高、工数: 1.5時間）

#### 3.1 現状分析

**独自実装**: `lib/oauth2/http_client.mbt`
- `base64_encode_internal()` (約50行)
- URL-safe Base64エンコーディング
- パディング制御

**使用箇所**:
- `pkce.mbt`: PKCE code_challenge
- `authorization_request.mbt`: state, nonce
- その他認証情報のエンコーディング

#### 3.2 移行方針

**使用ライブラリ**: `moonbitlang/x/codec/base64`

**API**:
```moonbit
@base64.encode(bytes_view, url_safe: true) -> String
```

**移行ステップ**:
1. `base64url_encode()`を`@base64.encode()`に置き換え
2. StringをBytesに変換する処理を追加
3. url_safeフラグをtrueに設定
4. パディング除去処理を確認
5. テスト実行

**注意点**:
- `@base64.encode()`は`BytesView`を受け取る
- Stringからの変換が必要
- パディング制御の互換性確認

### Phase 4: JSON処理の統一（優先度: 中、工数: 1時間）

#### 4.1 現状分析

**確認が必要な箇所**:
- `token_request.mbt`: TokenResponseのJSONパース
- `error.mbt`: エラーレスポンスのJSONパース
- その他JSONを扱う箇所

#### 4.2 移行方針

**使用パッケージ**: `moonbitlang/core/json`

**確認事項**:
1. 現在のJSON処理方法を調査
2. `@json`パッケージの使用状況
3. 文字列操作によるパースがあれば置き換え

**移行ステップ**:
1. JSON処理箇所の特定
2. `@json.parse()`を使用した実装に置き換え
3. パターンマッチによる型安全な値の取り出し
4. テスト実行

### Phase 5: コード品質の向上（優先度: 低、工数: 1時間）

#### 5.1 ネストしたパターンマッチのguard節化

**調査結果**: 初期調査では該当箇所が見つからなかった

**対応**:
1. 詳細なコードレビューで該当箇所を探す
2. 見つかった場合のみ対応
3. 可読性が向上する場合のみ変更

**guard節の例**:

**改善前**:
```moonbit
match result {
  Ok(value) =>
    match value.field {
      Some(f) =>
        if f > 0 {
          // 処理
        }
      None => // エラー
    }
  Err(e) => // エラー
}
```

**改善後**:
```moonbit
match result {
  Ok(value) if value.field == Some(f) && f > 0 => {
    // 処理
  }
  Ok(_) => // エラー
  Err(e) => // エラー
}
```

## スコープ

### 含むもの

1. **OAuth2HttpClientのデバッグ制御**
   - `debug: Bool`フィールドの追加
   - `new_with_debug()`コンストラクタ
   - 全デバッグ出力の条件化（17箇所）

2. **SHA256のライブラリ化**
   - `@crypto/sha256`への移行
   - 独自実装の削除または非推奨化
   - PKCEでの動作確認

3. **Base64URLのライブラリ化**
   - `@base64.encode()`への移行
   - 独自実装の削除
   - 全使用箇所の動作確認

4. **JSON処理の確認と改善**
   - 現状の調査
   - 必要に応じて`@json`パッケージの活用

5. **テストの維持**
   - 全テストがパス
   - リファクタリング後の動作確認
   - OIDC検証テストの成功

### 含まないもの

1. **外部APIの変更**
   - 既存のpublic関数のシグネチャは変更しない
   - 後方互換性を維持

2. **新機能の追加**
   - リファクタリングに集中
   - 機能追加は別タスク

3. **大規模な構造変更**
   - ファイル構成は維持
   - モジュール構造は維持

4. **パフォーマンス最適化**
   - リファクタリングが主目的
   - 性能改善は副次的効果

## 影響範囲

### 変更ファイル

```
lib/oauth2/
├── http_client.mbt      # OAuth2HttpClient構造体、デバッグ出力制御
├── sha256.mbt           # 削除または非推奨化
├── pkce.mbt             # SHA256、Base64の使用箇所更新
├── authorization_request.mbt  # Base64の使用箇所更新（あれば）
├── token_request.mbt    # JSON処理の確認・改善
├── error.mbt            # JSON処理の確認・改善
└── moon.pkg             # 依存関係の確認（既に追加済み）
```

### テストファイル

```
lib/oauth2/
├── http_client_wbtest.mbt      # デバッグ制御のテスト追加
├── sha256_wbtest.mbt           # ライブラリ移行後のテスト
├── pkce_wbtest.mbt             # RFC 7636テストベクター確認
└── その他のテストファイル      # リグレッションテスト
```

### 影響を受けるコンポーネント

- **PKCE実装** (`pkce.mbt`)
  - SHA256の使用
  - Base64URLの使用
  - 動作確認が重要

- **認証リクエスト** (`authorization_request.mbt`)
  - CSRFトークン生成（Base64使用の可能性）
  - nonceパラメータ（Base64使用の可能性）

- **HTTPクライアント** (`http_client.mbt`)
  - デバッグ出力の全箇所
  - Base64エンコーディング

- **統合テスト**
  - Keycloak統合テスト
  - OIDC検証テスト

## 技術的な決定事項

### 1. SHA256ライブラリの選択

**選択肢**:
- A. moonbitlang/x/crypto を使用
- B. 独自実装を維持
- C. 外部ライブラリを探す

**決定**: **A. moonbitlang/x/crypto**

**理由**:
- 公式ライブラリで信頼性が高い
- メンテナンスコストの削減
- 192行のコード削減
- パフォーマンスは同等以上と期待

### 2. Base64ライブラリの選択

**選択肢**:
- A. moonbitlang/x/codec/base64 を使用
- B. 独自実装を維持

**決定**: **A. moonbitlang/x/codec/base64**

**理由**:
- RFC 4648準拠の実装
- url_safeフラグのサポート
- コードの簡潔化
- 標準ライブラリとの一貫性

### 3. デバッグ出力のデフォルト設定

**選択肢**:
- A. デフォルトでデバッグ有効
- B. デフォルトでデバッグ無効

**決定**: **B. デフォルトでデバッグ無効**

**理由**:
- 本番環境での不要な出力を防ぐ
- ユーザーが明示的に有効化
- 既存コードへの影響を最小化（デフォルトコンストラクタは無効）

### 4. 独自実装の扱い

**決定**: 削除

**理由**:
- ライブラリ移行後は不要
- コードベースの簡潔化
- 混乱を避ける

**代替案**: `deprecated.mbt`に移動（将来的な参照用）

## 実装順序

### Phase 1: デバッグ出力制御 (1時間)

1. `OAuth2HttpClient`構造体の変更
2. `new()`と`new_with_debug()`の実装
3. `post()`メソッドのデバッグ出力条件化（9箇所）
4. `get()`メソッドのデバッグ出力条件化（8箇所）
5. テスト実行
6. OIDC検証テストの実行（デバッグ無効で）

### Phase 2: SHA256移行 (2時間)

7. `@crypto`パッケージAPIの調査
8. `sha256()`関数の置き換え
9. `sha256_hex()`関数の置き換え
10. `pkce.mbt`での動作確認
11. RFC 7636テストベクターの実行
12. 全テストの実行
13. `sha256.mbt`の削除

### Phase 3: Base64URL移行 (1.5時間)

14. `@base64`パッケージAPIの調査
15. `base64url_encode()`の置き換え実装
16. StringからBytesへの変換処理
17. 全使用箇所の更新
18. テスト実行
19. 独自実装の削除

### Phase 4: JSON処理確認 (1時間)

20. JSON処理箇所の特定
21. 現状の実装確認
22. 必要に応じて改善
23. テスト実行

### Phase 5: 最終確認 (30分)

24. 全テスト実行（Native/JS）
25. OIDC検証テスト実行
26. コードレビュー
27. 完了ドキュメント作成

## テスト戦略

### 単体テスト

各変更に対して：

1. **デバッグ出力**
   - `debug: false`でprintln出力がないことを確認
   - `debug: true`でprintln出力があることを確認

2. **SHA256**
   - RFC 7636テストベクター（既存）
   - ライブラリ版と独自実装版の出力が一致

3. **Base64URL**
   - 既存のPKCEテスト
   - URL-safe文字のみ使用
   - パディングなし

### 統合テスト

1. **全ユニットテストの実行**
   ```bash
   moon test --target native
   moon test --target js
   ```

2. **OIDC検証テスト**
   ```bash
   ./scripts/verify_oidc.sh
   ```

3. **Keycloak統合テスト**
   ```bash
   ./scripts/test_keycloak_moonbit.sh
   ```

### リグレッションテスト

全ての既存テストがパスすることを確認：
- OAuth2テスト: 132テスト
- OIDCテスト: 28/29テスト成功

## リスクと対策

### リスク1: SHA256ライブラリの互換性

**リスク**: `@crypto/sha256`のAPIが独自実装と異なる

**対策**:
- 事前にAPIドキュメントを確認
- RFC 7636テストベクターで検証
- 問題があれば独自実装を維持

### リスク2: Base64URLパディング

**リスク**: ライブラリがパディング除去をサポートしない

**対策**:
- パディング除去を手動で実装
- または独自実装を維持

### リスク3: テスト失敗

**リスク**: リファクタリング後にテストが失敗

**対策**:
- 段階的な移行（Phase毎にテスト）
- 問題発生時は即座にロールバック
- コミットを小さく保つ

### リスク4: パフォーマンス低下

**リスク**: ライブラリ版がパフォーマンス低下を引き起こす

**対策**:
- RFC 7636テストベクターで性能確認
- 大きな差があれば独自実装を維持
- ベンチマークテストの追加（オプション）

## 成功の基準

### 必須条件

1. **全テストがパス**
   - ✅ OAuth2ユニットテスト（132テスト）
   - ✅ OIDC検証テスト（28/29テスト）
   - ✅ 既存の統合テスト

2. **デバッグ出力の制御**
   - ✅ デフォルトでデバッグ出力なし
   - ✅ `debug: true`で出力あり

3. **コード削減**
   - ✅ sha256.mbtの削除（約192行）
   - ✅ Base64独自実装の削除（約50行）
   - ✅ 合計約250行のコード削減

4. **後方互換性**
   - ✅ 既存のpublic APIが動作
   - ✅ 外部から見た動作が同じ

### 推奨条件

5. **コード品質の向上**
   - ✅ 標準ライブラリの活用
   - ✅ 保守性の向上
   - ✅ 可読性の向上

6. **ドキュメント更新**
   - ✅ 完了ドキュメントの作成
   - ✅ 変更内容の記録

## 次のステップ

1. **このSteeringドキュメントのレビュー**
   - 内容の確認
   - アプローチの妥当性確認

2. **Phase 1の開始**
   - デバッグ出力制御の実装
   - テスト実行

3. **段階的な実装**
   - 各Phaseごとにテスト
   - 問題があれば調整

4. **完了ドキュメント作成**
   - 実装内容のまとめ
   - 削減されたコード行数
   - テスト結果

## 参考資料

### MoonBit標準ライブラリ

- [moonbitlang/x/crypto](https://mooncakes.io/docs/moonbitlang/x/crypto/)
- [moonbitlang/x/codec/base64](https://mooncakes.io/docs/moonbitlang/x/codec/base64/)
- [moonbitlang/core/json](https://mooncakes.io/docs/moonbitlang/core/json/)

### RFC仕様

- [RFC 6234 - SHA-256](https://tools.ietf.org/html/rfc6234)
- [RFC 4648 - Base64](https://tools.ietf.org/html/rfc4648)
- [RFC 7636 - PKCE](https://tools.ietf.org/html/rfc7636)

### 既存ドキュメント

- `docs/steering/20260215_oauth2_implementation_planning.md`
- `docs/completed/20260216_oidc_verification_implementation.md`
- `Todo.md`
