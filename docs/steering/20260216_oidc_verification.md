# Steering: OIDC実装の動作検証

実施日: 2026-02-16

## 目的・背景

OIDC Phase 1の実装が完了しましたが、実環境（Keycloak）での動作検証が未実施です。実装した機能が正しく動作することを確認し、問題があれば修正する必要があります。

### なぜ動作検証が必要か

1. **実装の正当性確認**
   - ID Tokenのパースが実際のOIDCプロバイダーで動作するか
   - UserInfo Endpointとの統合が正しく動作するか
   - nonceパラメータが正しく処理されるか

2. **相互運用性の確保**
   - Keycloak（業界標準のOIDCプロバイダー）との互換性
   - 実際のJWT形式への対応
   - 標準的なOIDCフローへの準拠

3. **問題の早期発見**
   - ユニットテストでは検出できない統合の問題
   - エッジケースやエラーハンドリングの問題
   - パフォーマンスや実用性の問題

4. **ドキュメント化**
   - 検証手順のスクリプト化
   - ユーザーが実環境で試すための手順書
   - トラブルシューティングガイド

## ゴール

1. **自動化された検証スクリプトの作成**
   - Keycloak環境のセットアップ
   - OIDCフローの実行と検証
   - 期待される結果の自動確認

2. **手動検証ドキュメントの作成**
   - ステップバイステップの検証手順
   - 各ステップでの期待される結果
   - トラブルシューティング情報

3. **機能の動作確認**
   - ID Tokenの取得とパース
   - ID Token内のクレーム検証
   - UserInfo Endpointからの情報取得
   - nonceパラメータの動作確認

4. **CI/CD統合**
   - GitHub Actionsでの自動検証
   - PR作成時の自動テスト
   - リグレッション防止

## アプローチ

### 1. 検証スクリプトの作成

既存の `test_keycloak_moonbit.sh` と `lib/keycloak_test/main.mbt` を拡張してOIDC対応を追加します。

#### 新規スクリプト: `scripts/verify_oidc.sh`

- Keycloak環境の起動（docker-compose）
- OIDC設定の確認
- MoonBit OIDCテストの実行
- 結果の検証とレポート出力

#### MoonBitテストコード: `lib/keycloak_test/oidc_verification.mbt`

以下の機能をテスト:

1. **Password Grant FlowでのID Token取得**
   - OIDCスコープ（openid, profile, email）を含むリクエスト
   - TokenResponseにid_tokenが含まれることを確認
   - ID Tokenのパース

2. **ID Tokenの内容検証**
   - 必須クレーム（iss, sub, aud, exp, iat）の存在確認
   - クレームの値の妥当性チェック
   - JWT形式の検証（header.payload.signature）

3. **UserInfo Endpointの検証**
   - Access Tokenを使用したUserInfo取得
   - subクレームがID Tokenと一致することを確認
   - 追加のユーザー情報（email, name等）の取得

4. **nonce パラメータの検証**
   - nonceを含むAuthorization URLの生成
   - nonceがクエリパラメータに含まれることを確認

### 2. 検証ドキュメントの作成

#### ドキュメント: `docs/verification/oidc_verification_guide.md`

内容:
- 検証の目的と範囲
- 前提条件（Docker、jq等）
- 自動検証の実行方法
- 手動検証の手順
- 期待される結果
- トラブルシューティング
- よくある問題と解決方法

### 3. 検証項目

#### Phase 1で検証すべき項目

| # | 検証項目 | 方法 | 期待結果 |
|---|---------|------|---------|
| 1 | ID Token取得（Password Grant） | OIDCスコープでトークン取得 | TokenResponseにid_tokenフィールドが存在 |
| 2 | ID Tokenのパース | `IdToken::parse()` | 成功してIdToken構造体を取得 |
| 3 | JWT形式の検証 | 3部分に分割（header.payload.signature） | 正しく分割できる |
| 4 | Base64URLデコード | header, payloadのデコード | JSON文字列を取得 |
| 5 | 必須クレームの存在 | iss, sub, aud, exp, iat | 全て存在する |
| 6 | issuerの値 | issクレーム | Keycloakのissuer URLと一致 |
| 7 | audienceの値 | audクレーム | client_idと一致 |
| 8 | subjectの値 | subクレーム | ユーザーIDが存在 |
| 9 | 有効期限 | expクレーム | 現在時刻より未来 |
| 10 | 発行時刻 | iatクレーム | 現在時刻より過去 |
| 11 | オプションクレーム | email, name等 | 取得できる（存在する場合） |
| 12 | UserInfo取得 | UserInfoRequest::execute() | 成功してUserInfo取得 |
| 13 | UserInfo sub一致 | ID TokenのsubとUserInfoのsub | 一致する |
| 14 | UserInfo追加情報 | email, name, picture等 | 取得できる |
| 15 | nonce URL生成 | AuthorizationRequest::with_nonce() | URLにnonceパラメータが含まれる |

#### Phase 2以降で検証すべき項目（参考）

- ID Token署名検証（RS256）
- JWKSの取得
- Claims検証（有効期限、nonce一致等）
- Discovery Documentの取得

### 4. スクリプト構成

```
scripts/
├── setup_keycloak.sh          # 既存（拡張不要）
├── test_keycloak_moonbit.sh   # 既存（OAuth2用）
└── verify_oidc.sh             # 新規（OIDC検証用）
```

```
lib/keycloak_test/
├── main.mbt                   # 既存（OAuth2テスト）
├── oidc_verification.mbt      # 新規（OIDC検証テスト）
└── moon.pkg                   # 依存関係にoidcを追加
```

## スコープ

### 含むもの

1. **検証スクリプト**
   - `scripts/verify_oidc.sh`: OIDC検証の実行スクリプト
   - 環境変数の設定
   - テスト実行とレポート

2. **MoonBitテストコード**
   - `lib/keycloak_test/oidc_verification.mbt`: OIDC機能のテスト
   - Password Grant FlowでのID Token取得
   - ID Tokenのパースと検証
   - UserInfo Endpointの検証

3. **検証ドキュメント**
   - `docs/verification/oidc_verification_guide.md`: 検証手順書
   - 自動検証の実行方法
   - 手動検証の手順
   - トラブルシューティング

4. **README更新**
   - OIDCセクションの追加
   - 検証方法の説明
   - サンプルコードの追加

### 含まないもの

1. **Phase 2以降の機能テスト**
   - 署名検証（RS256）
   - JWKS統合
   - Discovery Document
   - これらは別途Phase 2の検証として実施

2. **他のOIDCプロバイダーとの検証**
   - Google、GitHub等は将来的な課題
   - Phase 1ではKeycloakのみ

3. **パフォーマンステスト**
   - 負荷テスト
   - ベンチマーク
   - これらは別タスク

4. **Authorization Code Flowの完全なE2Eテスト**
   - ブラウザ操作が必要（Phase 1では手動確認のみ）
   - 自動化は将来的な課題

## 影響範囲

### 新規ファイル

```
scripts/
└── verify_oidc.sh                    # OIDC検証スクリプト（約200行）

lib/keycloak_test/
└── oidc_verification.mbt             # OIDCテストコード（約400-500行）

docs/verification/
└── oidc_verification_guide.md        # 検証ドキュメント（約300行）
```

### 変更ファイル

```
lib/keycloak_test/
└── moon.pkg                          # @oidc依存を追加

README.mbt.md                         # OIDCセクションを追加

.github/workflows/test.yml            # OIDC検証ステップを追加（オプション）
```

### 影響を受けるコンポーネント

- **Keycloak環境**: 既存のdocker-compose.ymlを使用（変更不要）
- **OAuth2テスト**: 既存テストに影響なし（並行して実行可能）
- **CI/CD**: OIDC検証を追加ステップとして統合

## 技術的な決定事項

### 1. テストコードの配置

**選択肢**:
- A. 既存の `main.mbt` に追加
- B. 新規ファイル `oidc_verification.mbt` を作成

**決定**: **B. 新規ファイルを作成**

**理由**:
- OAuth2とOIDCの関心を分離
- テストの独立性を保つ
- 将来的にOIDCテストのみを実行可能

### 2. テスト実行方法

**選択肢**:
- A. `moon test` でユニットテストとして実行
- B. `moon run` で統合テストとして実行
- C. 両方サポート

**決定**: **B. `moon run` で統合テスト**

**理由**:
- Keycloak環境が必要（外部依存）
- ユニットテストは高速実行が期待される
- 統合テストは手動またはCI/CDで実行

### 3. エラーハンドリング

**方針**:
- テスト失敗時は明確なエラーメッセージを出力
- 各検証項目の成功/失敗を個別に表示
- 最終的なサマリーを表示

### 4. ID Token検証のレベル

**Phase 1での検証範囲**:
- ✅ パース成功
- ✅ クレームの存在確認
- ✅ クレームの値の型チェック
- ❌ 署名検証（Phase 2）
- ❌ 有効期限の厳密な検証（Phase 2）
- ❌ nonce一致検証（Phase 2）

**理由**: Phase 1は基本機能の動作確認に注力

### 5. スクリプトの実行順序

```bash
# 1. Keycloak環境のセットアップ（初回のみ）
./scripts/setup_keycloak.sh

# 2. OIDC検証の実行
./scripts/verify_oidc.sh

# 3. OAuth2検証も実行可能（並行）
./scripts/test_keycloak_moonbit.sh
```

## 実装順序

### ステップ1: テストコードの作成（約2-3時間）

1. **`lib/keycloak_test/oidc_verification.mbt` の作成**
   - Password Grant FlowでのID Token取得テスト
   - ID Tokenパーステスト
   - UserInfo取得テスト
   - nonce URL生成テスト

2. **`lib/keycloak_test/moon.pkg` の更新**
   - `@oidc` パッケージへの依存を追加

### ステップ2: 検証スクリプトの作成（約1-2時間）

3. **`scripts/verify_oidc.sh` の作成**
   - 環境変数の設定
   - Keycloak起動確認
   - `moon run lib/keycloak_test/oidc_verification` の実行
   - 結果の表示

### ステップ3: 検証ドキュメントの作成（約1-2時間）

4. **`docs/verification/oidc_verification_guide.md` の作成**
   - 検証の目的と範囲
   - 前提条件
   - 自動検証の手順
   - 手動検証の手順
   - トラブルシューティング

### ステップ4: 動作確認（約1時間）

5. **実際に検証を実行**
   - Keycloak環境での動作確認
   - スクリプトの動作確認
   - エラーがあれば修正

### ステップ5: ドキュメント更新（約30分）

6. **README.mbt.md の更新**
   - OIDCセクションの追加
   - 検証方法の説明
   - サンプルコードの追加

### ステップ6: 完了ドキュメント作成（約30分）

7. **完了報告の作成**
   - 実装内容のまとめ
   - 検証結果
   - 今後の課題

## テスト戦略

### 自動テスト

```moonbit
// lib/keycloak_test/oidc_verification.mbt

async fn test_id_token_acquisition(config: Config) -> Unit {
  // Password Grant FlowでID Token取得
  // TokenResponseにid_tokenが存在することを確認
}

async fn test_id_token_parsing(config: Config) -> Unit {
  // ID Tokenのパース
  // 必須クレームの存在確認
}

async fn test_userinfo_endpoint(config: Config) -> Unit {
  // UserInfo取得
  // subの一致確認
}

fn test_nonce_parameter() -> Unit {
  // nonceを含むAuthorization URL生成
  // URLパラメータの確認
}
```

### 手動テスト

1. **ブラウザでの Authorization Code Flow**
   - 生成されたURLをブラウザで開く
   - Keycloakログイン
   - コールバック確認

2. **curlでの動作確認**
   - トークン取得
   - UserInfo取得
   - レスポンスの確認

### CI/CD統合（オプション）

`.github/workflows/test.yml` に追加:

```yaml
- name: OIDC Verification
  run: |
    ./scripts/setup_keycloak.sh
    ./scripts/verify_oidc.sh
```

## 参考資料

### Keycloak関連

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak REST API](https://www.keycloak.org/docs-api/latest/rest-api/)
- [Keycloak Docker Image](https://quay.io/repository/keycloak/keycloak)

### OIDC仕様

- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [RFC 7519 - JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519)

### 既存ドキュメント

- `docs/testing/keycloak_verification_guide.md`: OAuth2検証ガイド
- `docs/completed/20260216_oidc_phase1_implementation.md`: Phase 1実装報告

## リスクと対策

### リスク1: Keycloak環境のセットアップ失敗

**リスク**: Docker環境の問題でKeycloakが起動しない

**対策**:
- 詳細なエラーメッセージの表示
- トラブルシューティングガイドの作成
- 既存の `setup_keycloak.sh` が動作することを前提

### リスク2: ID Tokenのフォーマット不一致

**リスク**: Keycloakが返すID Tokenの形式が想定と異なる

**対策**:
- 実際のID Tokenをログ出力して確認
- エラーメッセージで具体的な問題箇所を示す
- 必要に応じてパース処理を修正

### リスク3: クロスプラットフォーム互換性

**リスク**: Native/JSターゲットで動作が異なる

**対策**:
- Phase 1ではJSターゲットで検証（既存のOAuth2テストと同様）
- Nativeターゲットの検証は別途実施
- プラットフォーム固有の問題を文書化

### リスク4: CI/CD統合の複雑化

**リスク**: GitHub ActionsでDocker環境の問題

**対策**:
- Phase 1ではローカル検証を優先
- CI/CD統合は別タスクとして実施
- 既存のOAuth2テストがCI/CDで動作していることを確認

## 成功の基準

### 必須条件

1. **スクリプトが正常に実行できる**
   - `./scripts/verify_oidc.sh` がエラーなく完了
   - 全ての検証項目がパス

2. **ID Tokenが取得できる**
   - Password Grant Flowで id_token を含むレスポンス取得
   - ID Tokenのパースが成功

3. **クレームが正しく取得できる**
   - 必須クレーム（iss, sub, aud, exp, iat）が存在
   - 値が妥当（型と内容）

4. **UserInfoが取得できる**
   - UserInfo Endpointから情報取得
   - subクレームがID Tokenと一致

5. **ドキュメントが整備されている**
   - 検証手順が明確
   - トラブルシューティング情報が充実

### 推奨条件

6. **エラーハンドリングが適切**
   - 各検証項目の成功/失敗が明確
   - 失敗時のエラーメッセージが有用

7. **再現性がある**
   - 同じ手順で同じ結果が得られる
   - 環境依存が最小限

8. **拡張性がある**
   - Phase 2の検証を追加しやすい構造
   - 他のOIDCプロバイダーにも対応可能な設計

## 次のステップ

1. **このSteeringドキュメントのレビュー**
   - アプローチの確認
   - スコープの調整

2. **実装開始**
   - ステップ1から順に実装
   - 各ステップで動作確認

3. **動作検証**
   - Keycloak環境での実行
   - 問題があれば修正

4. **完了ドキュメント作成**
   - 実装内容のまとめ
   - 検証結果の記録
   - 今後の課題の整理

5. **Phase 2の準備**
   - 署名検証の設計
   - JWKSの実装計画
