# 完了報告: mooncakes.ioドキュメントエラー修正

## 実装内容
- `lib/` 内の実行可能パッケージ（`is-main: true`）を `cmd/` に移動
- `moon info` によるインターフェースファイルの自動更新（derive表記への変更）

## 技術的な決定事項
- `lib/keycloak_test/` → `cmd/keycloak_test/` に移動
  - 理由: `source: "lib"` で公開されるディレクトリに実行可能パッケージを含めるべきではない
- `lib/google_discovery_example/` → `cmd/google_discovery_example/` に移動
  - 理由: 同上
- importパスは外部パッケージ参照（`ryota0624/oauth2` 等）のため変更不要

## 変更ファイル一覧
- 移動:
  - `lib/keycloak_test/` → `cmd/keycloak_test/`（README.md, main.mbt, moon.pkg, oidc_verification.mbt, pkg.generated.mbti）
  - `lib/google_discovery_example/` → `cmd/google_discovery_example/`（main.mbt, moon.pkg, pkg.generated.mbti）
- 更新（自動生成）:
  - `lib/pkg.generated.mbti`: derive表記への更新
  - `lib/oidc/pkg.generated.mbti`: derive表記への更新
  - `lib/providers/google/pkg.generated.mbti`: derive表記への更新

## テスト
- `moon check`: 成功
- `moon test`: 全189テストパス
- `moon info && moon fmt`: 正常完了

## 今後の課題・改善点
- [ ] バージョンを更新してmooncakes.ioに再publishし、ドキュメントが表示されることを確認
- [ ] `examples/google/` ディレクトリも同様にlib外であることを確認

## 参考資料
- mooncakes.io `ryota0624/oauth2@0.2.0` ドキュメントページのJSランタイムエラー
- `ryota0624/googleauth` リポジトリの構造（`cmd/main/` に実行可能コードを分離する設計パターン）
