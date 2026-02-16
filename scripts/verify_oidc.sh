#!/bin/bash
set -e

# Keycloak OIDC 検証スクリプト (MoonBit 版)
# MoonBit の OIDC 実装を使用して Keycloak をテストします

echo "========================================="
echo "Keycloak OIDC 検証 (MoonBit)"
echo "========================================="
echo ""

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Keycloak が起動しているか確認
echo -e "${YELLOW}[1/4] Keycloak の起動確認...${NC}"
if ! curl -s http://localhost:8080/health/ready > /dev/null 2>&1; then
    echo -e "${RED}✗ Keycloak が起動していません${NC}"
    echo ""
    echo "以下のコマンドで Keycloak を起動してください:"
    echo "  docker compose up -d keycloak postgres"
    echo ""
    echo "または、セットアップスクリプトを実行:"
    echo "  ./scripts/setup_keycloak.sh"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Keycloak が起動しています${NC}"
echo ""

# Client Secret を環境変数から取得
echo -e "${YELLOW}[2/4] Client Secret の確認...${NC}"
if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${YELLOW}CLIENT_SECRET が設定されていません。自動取得を試みます...${NC}"
    echo ""

    # Keycloak 管理 API から取得を試みる
    if command -v jq >/dev/null 2>&1; then
        # 管理者トークンを取得
        ADMIN_TOKEN=$(curl -s -X POST 'http://localhost:8080/realms/master/protocol/openid-connect/token' \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            -d 'username=admin' \
            -d 'password=admin' \
            -d 'grant_type=password' \
            -d 'client_id=admin-cli' 2>/dev/null | jq -r '.access_token' 2>/dev/null)

        if [ -n "$ADMIN_TOKEN" ] && [ "$ADMIN_TOKEN" != "null" ]; then
            # Client UUID を取得
            REALM="${KEYCLOAK_REALM:-test-realm}"
            CLIENT_ID="${CLIENT_ID:-test-client}"

            CLIENT_UUID=$(curl -s -X GET \
                -H "Authorization: Bearer ${ADMIN_TOKEN}" \
                "http://localhost:8080/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" 2>/dev/null | \
                jq -r '.[0].id' 2>/dev/null)

            if [ -n "$CLIENT_UUID" ] && [ "$CLIENT_UUID" != "null" ]; then
                # Client Secret を取得
                export CLIENT_SECRET=$(curl -s -X GET \
                    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
                    "http://localhost:8080/admin/realms/${REALM}/clients/${CLIENT_UUID}/client-secret" 2>/dev/null | \
                    jq -r '.value' 2>/dev/null)

                if [ -n "$CLIENT_SECRET" ] && [ "$CLIENT_SECRET" != "null" ]; then
                    echo -e "${GREEN}✓ Client Secret を自動取得しました${NC}"
                    echo ""
                fi
            fi
        fi
    fi

    # まだ取得できていない場合はエラー
    if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" = "null" ]; then
        echo -e "${RED}✗ CLIENT_SECRET の取得に失敗しました${NC}"
        echo ""
        echo "以下の方法で CLIENT_SECRET を設定してください:"
        echo ""
        echo "1. セットアップスクリプトを実行:"
        echo "   ./scripts/setup_keycloak.sh"
        echo ""
        echo "2. または手動で環境変数を設定:"
        echo "   export CLIENT_SECRET=\"your-client-secret-here\""
        echo ""
        exit 1
    fi
else
    echo -e "${GREEN}✓ CLIENT_SECRET が設定されています${NC}"
    echo ""
fi

# デフォルト値の設定
export KEYCLOAK_REALM="${KEYCLOAK_REALM:-test-realm}"
export KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-http://localhost:8080/realms/${KEYCLOAK_REALM}}"
export TOKEN_ENDPOINT="${TOKEN_ENDPOINT:-${KEYCLOAK_BASE_URL}/protocol/openid-connect/token}"
export CLIENT_ID="${CLIENT_ID:-test-client}"
export TEST_USERNAME="${TEST_USERNAME:-testuser}"
export TEST_PASSWORD="${TEST_PASSWORD:-testpass123}"

echo -e "${YELLOW}[3/4] 設定情報:${NC}"
echo "  Realm: ${KEYCLOAK_REALM}"
echo "  Base URL: ${KEYCLOAK_BASE_URL}"
echo "  Token Endpoint: ${TOKEN_ENDPOINT}"
echo "  Client ID: ${CLIENT_ID}"
echo "  Test User: ${TEST_USERNAME}"
echo ""

# OIDC 検証の実行
echo -e "${YELLOW}[4/4] OIDC 検証を実行中...${NC}"
echo ""

cd "$(dirname "$0")/.."

# moon run を実行（ビルド + 実行）
# MODE=oidc を設定してOIDC検証モードで実行
if MODE=oidc moon run lib/keycloak_test; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}検証完了${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${GREEN}✓ すべての OIDC 検証が成功しました${NC}"
    echo ""
    echo "📖 詳細情報:"
    echo "  - ドキュメント: docs/verification/oidc_verification_guide.md"
    echo "  - Steering: docs/steering/20260216_oidc_verification.md"
    echo "  - 実装報告: docs/completed/20260216_oidc_phase1_implementation.md"
    echo ""
else
    echo ""
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}検証失敗${NC}"
    echo -e "${RED}=========================================${NC}"
    echo ""
    echo -e "${RED}✗ OIDC 検証中にエラーが発生しました${NC}"
    echo ""
    echo "📖 トラブルシューティング:"
    echo "  1. Keycloak が正しく起動しているか確認"
    echo "     docker compose logs keycloak"
    echo ""
    echo "  2. test-realm と test-client が存在するか確認"
    echo "     ./scripts/setup_keycloak.sh"
    echo ""
    echo "  3. testuser が存在するか確認"
    echo "     http://localhost:8080/admin"
    echo ""
    exit 1
fi
