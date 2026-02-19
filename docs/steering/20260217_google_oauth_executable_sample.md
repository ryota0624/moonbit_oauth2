# Steering: Google OAuth2実行可能サンプルの作成

## 目的・背景
examples/google/README.mdに記載されているGoogle OAuth2認証のサンプルコードは、説明目的のため実行できない形になっています。実際にGoogle OAuth2フローを試すために、実行可能なサンプルプログラムを作成します。

## ゴール
- README記載の「Authorization Code Flow with PKCE」を実行可能なプログラムに変換
- 環境変数からクレデンシャル情報を取得
- authorization codeは標準入力から取得
- ユーザーが実際にGoogle OAuth2認証フローを試せる状態にする

## アプローチ
- examples/google/main.mbtを作成し、実行可能なコードを配置
- 環境変数読み取りにはMoonBitの標準機能を使用
- 標準入力の読み取りは@moonbitlang/x/io等を使用
- READMEのコード構造を維持しつつ、実行に必要な部分を補完

## スコープ
- 含む:
  - Authorization Code Flow with PKCEの完全な実装
  - 環境変数からのclient_id、client_secret、redirect_uri取得
  - authorization codeの標準入力からの取得
  - エラーハンドリングの追加

- 含まない:
  - Webサーバーの実装（authorization codeの受け取りは手動）
  - ID Token Verificationのみのサンプル
  - UserInfo取得のみのサンプル

## 影響範囲
- 追加ファイル:
  - examples/google/main.mbt: 実行可能なサンプルコード
  - examples/google/moon.pkg.json: パッケージ設定（既存なら更新）

- 変更ファイル:
  - examples/google/README.md: 実行方法の説明を追加（必要に応じて）
