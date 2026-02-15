#!/bin/bash
set -e

# Keycloak OAuth2 検証スクリプト (MoonBit 版)
# MoonBit の OAuth2 実装を使用して Keycloak をテストします

echo "========================================="
echo "Keycloak OAuth2 検証 (MoonBit)"
echo "========================================="
echo ""

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Client Secret を環境変数から取得
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
        echo "Client Secret は Keycloak 管理コンソールから取得できます:"
        echo "   http://localhost:8080/admin"
        echo "   → Clients → test-client → Credentials タブ"
        echo ""
        exit 1
    fi
fi

# デフォルト値の設定
export KEYCLOAK_REALM="${KEYCLOAK_REALM:-test-realm}"
export KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-http://localhost:8080/realms/${KEYCLOAK_REALM}}"
export TOKEN_ENDPOINT="${TOKEN_ENDPOINT:-${KEYCLOAK_BASE_URL}/protocol/openid-connect/token}"
export CLIENT_ID="${CLIENT_ID:-test-client}"
export TEST_USERNAME="${TEST_USERNAME:-testuser}"
export TEST_PASSWORD="${TEST_PASSWORD:-testpass123}"

echo -e "${YELLOW}MoonBit プログラムをビルド中...${NC}"
echo ""

# ビルド
cd "$(dirname "$0")/.."
moon build --target native lib/keycloak_test/main.mbt

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ビルドに失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ビルド完了${NC}"
echo ""

# 実行
echo -e "${YELLOW}テストを実行中...${NC}"
echo ""

./_build/native/debug/build/keycloak_test/keycloak_test.exe

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}完了${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
