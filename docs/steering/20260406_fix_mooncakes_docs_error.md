# Steering: mooncakes.ioドキュメントエラー修正

## 目的・背景
mooncakes.io の `ryota0624/oauth2@0.2.0` ドキュメントページでJSランタイムエラーが発生している。
`source: "lib"` で公開されるディレクトリ内に `is-main: true` の実行可能パッケージが含まれており、
ドキュメントレンダラーがクラッシュしている可能性が高い。

## ゴール
- `lib/` 内の実行可能パッケージ（keycloak_test, google_discovery_example）を公開ソース外に移動
- mooncakes.ioのドキュメントが正常に表示される状態にする
- `moon check` と `moon test` が通る状態を維持

## アプローチ
- `lib/keycloak_test/` → `cmd/keycloak_test/` に移動
- `lib/google_discovery_example/` → `cmd/google_discovery_example/` に移動
- 各 `moon.pkg` のimportパスを更新

## スコープ
- 含む: 実行可能パッケージの移動、moon.pkg更新
- 含まない: バージョン更新、再publish（ユーザー判断）

## 影響範囲
- `lib/keycloak_test/` → `cmd/keycloak_test/`
- `lib/google_discovery_example/` → `cmd/google_discovery_example/`
- 公開ライブラリコード（lib/, lib/oidc/, lib/providers/google/）への影響なし
