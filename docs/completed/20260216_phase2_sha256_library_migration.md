# 完了報告: Phase 2 - SHA256ライブラリ移行

## 実装内容

独自実装のSHA256ハッシュ関数を`moonbitlang/x/crypto`パッケージに置き換えました。

### 主要な変更点

1. **依存関係の追加**
   - `lib/oauth2/moon.pkg`に`moonbitlang/x/crypto`を追加

2. **PKCE実装の更新**
   - `from_verifier_s256()`メソッドで`@crypto.SHA256`を使用
   - String → FixedArray[Byte] 変換を実装
   - FixedArray[Byte] → String 変換を実装（Base64URL用）

3. **ファイル削除**
   - `lib/oauth2/sha256.mbt` (192行) - 独自SHA256実装
   - `lib/oauth2/sha256_wbtest.mbt` (11テスト) - SHA256テスト

## 技術的な決定事項

### ライブラリAPIの使用方法

```moonbit
// 1. SHA256コンテキストを作成
let hasher = @crypto.SHA256::new()

// 2. データを入力（ByteSourceを実装する型が必要）
let data = FixedArray::make(length, Byte::default())
hasher.update(data)

// 3. ハッシュ値を取得（FixedArray[Byte]）
let hash = hasher.finalize()
```

### String → FixedArray[Byte] 変換

```moonbit
let verifier_bytes = FixedArray::make(verifier.value.length(), Byte::default())
for i = 0; i < verifier.value.length(); i = i + 1 {
  verifier_bytes[i] = verifier.value[i].to_int().to_byte()
}
```

- `ByteSource` traitはString直接サポートしていない
- FixedArray[Byte]、BytesView、Bytesが実装済み
- FixedArray[Byte]を選択（シンプルで直接的）

### ハッシュ結果の処理

従来:
```moonbit
// Array[UInt] (8個の32ビットワード)
let hash_words = sha256(input)
```

新規:
```moonbit
// FixedArray[Byte] (32バイト)
let hash_bytes = hasher.finalize()
```

## 変更ファイル一覧

### 変更
- **lib/oauth2/moon.pkg**
  - `moonbitlang/x/crypto`依存関係追加

- **lib/oauth2/pkce.mbt**
  - `from_verifier_s256()`メソッド更新
  - 独自sha256()呼び出し → @crypto.SHA256使用
  - String→FixedArray[Byte]変換追加

- **Todo.md**
  - Phase 2完了マーク追加

### 削除
- **lib/oauth2/sha256.mbt** (192行)
  - sha256() 関数
  - sha256_hex() 関数
  - 内部ヘルパー関数（pad_message, process_block等）

- **lib/oauth2/sha256_wbtest.mbt** (11テスト)
  - RFC 6234テストベクター検証
  - エッジケーステスト

### 生成
- **lib/oauth2/pkg.generated.mbti**
  - sha256()関数削除（公開API）
  - sha256_hex()関数削除（公開API）

## テスト

### ユニットテスト
- 削除前: 124テスト
- 削除後: 113テスト（-11 SHA256テスト）
- **結果: 113/113 テスト成功** ✅

### PKCEテスト
- RFC 7636テストベクター: パス ✅
- ランダムverifier生成: パス ✅
- S256 challenge計算: パス ✅

### 型チェック
- `moon check lib/oauth2`: エラーなし ✅

### 動作確認方法
```bash
# PKCEテストを実行
moon test lib/oauth2 --filter pkce

# 統合テスト
./scripts/verify_oidc.sh
```

## 影響範囲

### 破壊的変更（公開API削除）
- `sha256(String) -> Array[UInt]` - 削除
- `sha256_hex(String) -> String` - 削除

**影響**: これらの関数は内部実装にのみ使用されており、外部から直接使用されていない想定。PKCEの公開APIは変更なし。

### 後方互換性
- PKCE公開API: 変更なし
  - `PkceCodeVerifier::new_random()`
  - `PkceCodeChallenge::from_verifier_s256()`
  - `PkceCodeChallenge::from_verifier_plain()`
- 既存のPKCE使用コードは影響なし ✅

### コード削減
- **192行削除** (sha256.mbt)
- 約20行追加（String変換ロジック）
- **正味 ~170行削減**

## メリット

1. **メンテナンス負荷軽減**
   - 暗号化アルゴリズムの保守不要
   - バグ修正・セキュリティパッチはライブラリ側で対応

2. **信頼性向上**
   - 公式ライブラリの使用
   - 広くテストされた実装

3. **コードサイズ削減**
   - 約170行削減

4. **一貫性**
   - プロジェクト全体で同じcryptoライブラリを使用
   - OIDCパッケージも同様の構造

## 次のステップ

Phase 3への準備:

1. **Base64URLエンコード移行の調査**
   - `moonbitlang/x/encoding` または `moonbitlang/core/base64` パッケージを確認
   - 現在の`base64url_encode()`実装（~50行）を確認

2. **統合テストの実行**
   - PKCEフローの動作確認
   - Keycloakとの実通信テスト

## 所要時間

- **実装**: 30分
  - ライブラリAPI調査: 10分
  - pkce.mbt更新: 10分
  - String変換実装: 5分
  - テスト実行: 5分
- **ドキュメント**: 10分（この文書）
- **合計**: 約40分

## 参考資料

- [moonbitlang/x/crypto](https://github.com/moonbitlang/x/tree/main/crypto) - 使用したライブラリ
- [RFC 6234](https://datatracker.ietf.org/doc/html/rfc6234) - SHA-256仕様
- [RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636) - PKCE仕様
- [pkce.mbt](../../lib/oauth2/pkce.mbt) - 変更されたソースコード

## まとめ

Phase 2「SHA256ライブラリ移行」を完了しました。独自実装（192行）を公式ライブラリに置き換え、コードサイズを削減しつつ信頼性を向上させました。全113テストが成功し、PKCE機能に影響はありません。

次は Phase 3: Base64URLライブラリ移行に進みます。
