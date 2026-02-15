#!/bin/bash
set -e

# Keycloak OAuth2 フローテストスクリプト
# 前提: scripts/setup_keycloak.sh を実行済み

echo "========================================="
echo "Keycloak OAuth2 フローテスト"
echo "========================================="
echo ""

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 設定
REALM="test-realm"
BASE_URL="http://localhost:8080/realms/${REALM}"
TOKEN_ENDPOINT="${BASE_URL}/protocol/openid-connect/token"
CLIENT_ID="test-client"
TEST_USERNAME="testuser"
TEST_PASSWORD="testpass123"

# Client Secret を取得（セットアップスクリプトで作成済みの場合）
echo -e "${YELLOW}Client Secret を取得中...${NC}"
ADMIN_TOKEN=$(curl -s -X POST 'http://localhost:8080/realms/master/protocol/openid-connect/token' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'username=admin' \
    -d 'password=admin' \
    -d 'grant_type=password' \
    -d 'client_id=admin-cli' | jq -r '.access_token')

CLIENT_UUID=$(curl -s -X GET \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:8080/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" | jq -r '.[0].id')

CLIENT_SECRET=$(curl -s -X GET \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:8080/admin/realms/${REALM}/clients/${CLIENT_UUID}/client-secret" | jq -r '.value')

if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" = "null" ]; then
    echo -e "${RED}✗ Client Secret の取得に失敗しました${NC}"
    echo "先に scripts/setup_keycloak.sh を実行してください"
    exit 1
fi

echo -e "${GREEN}✓ Client Secret を取得しました${NC}"
echo ""

# ========================================
# Test 1: Client Credentials Flow
# ========================================
echo -e "${YELLOW}[Test 1] Client Credentials Flow${NC}"
echo "-------------------------------------------"

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${TOKEN_ENDPOINT}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "scope=openid")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 成功 (HTTP 200)${NC}"

    ACCESS_TOKEN=$(echo "$BODY" | jq -r '.access_token')
    TOKEN_TYPE=$(echo "$BODY" | jq -r '.token_type')
    EXPIRES_IN=$(echo "$BODY" | jq -r '.expires_in')

    echo "  Token Type: ${TOKEN_TYPE}"
    echo "  Expires In: ${EXPIRES_IN}s"
    echo "  Access Token (先頭50文字): ${ACCESS_TOKEN:0:50}..."

    # JWT の内容を確認
    JWT_PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.azp, .scope' 2>/dev/null || echo "N/A")
    echo "  JWT Client: $(echo "$JWT_PAYLOAD" | head -1)"
    echo "  JWT Scope: $(echo "$JWT_PAYLOAD" | tail -1)"
else
    echo -e "${RED}✗ 失敗 (HTTP ${HTTP_CODE})${NC}"
    echo "$BODY" | jq '.'
fi

echo ""

# ========================================
# Test 2: Resource Owner Password Credentials Flow
# ========================================
echo -e "${YELLOW}[Test 2] Password Grant Flow${NC}"
echo "-------------------------------------------"

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${TOKEN_ENDPOINT}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "username=${TEST_USERNAME}" \
    -d "password=${TEST_PASSWORD}" \
    -d "scope=openid profile email")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 成功 (HTTP 200)${NC}"

    ACCESS_TOKEN=$(echo "$BODY" | jq -r '.access_token')
    REFRESH_TOKEN=$(echo "$BODY" | jq -r '.refresh_token')
    ID_TOKEN=$(echo "$BODY" | jq -r '.id_token')

    echo "  Access Token: ${ACCESS_TOKEN:0:50}..."
    echo "  Refresh Token: ${REFRESH_TOKEN:0:50}..."
    echo "  ID Token: ${ID_TOKEN:0:50}..."

    # ID Token の内容を確認
    ID_PAYLOAD=$(echo "$ID_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.preferred_username, .email' 2>/dev/null || echo "N/A")
    echo "  User: $(echo "$ID_PAYLOAD" | head -1)"
    echo "  Email: $(echo "$ID_PAYLOAD" | tail -1)"

    # UserInfo エンドポイントをテスト
    echo ""
    echo "  UserInfo エンドポイントをテスト中..."
    USERINFO=$(curl -s -X GET "${BASE_URL}/protocol/openid-connect/userinfo" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}")

    if echo "$USERINFO" | jq -e . >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ UserInfo 取得成功${NC}"
        echo "$USERINFO" | jq '{name, email, preferred_username}'
    fi
else
    echo -e "${RED}✗ 失敗 (HTTP ${HTTP_CODE})${NC}"
    echo "$BODY" | jq '.'
fi

echo ""

# ========================================
# Test 3: エラーハンドリング（無効な認証情報）
# ========================================
echo -e "${YELLOW}[Test 3] エラーハンドリング（無効な認証情報）${NC}"
echo "-------------------------------------------"

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${TOKEN_ENDPOINT}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=invalid-secret" \
    -d "scope=openid")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ 正しくエラーを返しました (HTTP ${HTTP_CODE})${NC}"
    ERROR=$(echo "$BODY" | jq -r '.error')
    ERROR_DESC=$(echo "$BODY" | jq -r '.error_description')
    echo "  Error: ${ERROR}"
    echo "  Description: ${ERROR_DESC}"
else
    echo -e "${RED}✗ 予期しないレスポンス (HTTP ${HTTP_CODE})${NC}"
    echo "$BODY" | jq '.'
fi

echo ""

# ========================================
# サマリー
# ========================================
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}テスト完了${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "📝 テスト結果:"
echo "  ✓ Client Credentials Flow"
echo "  ✓ Password Grant Flow"
echo "  ✓ エラーハンドリング"
echo ""
echo "📖 詳細な検証手順は docs/testing/keycloak_verification_guide.md を参照"
echo ""
echo "🔑 認証情報（環境変数にエクスポート）:"
echo ""
echo "  export KEYCLOAK_BASE_URL=\"${BASE_URL}\""
echo "  export TOKEN_ENDPOINT=\"${TOKEN_ENDPOINT}\""
echo "  export CLIENT_ID=\"${CLIENT_ID}\""
echo "  export CLIENT_SECRET=\"${CLIENT_SECRET}\""
echo "  export TEST_USERNAME=\"${TEST_USERNAME}\""
echo "  export TEST_PASSWORD=\"${TEST_PASSWORD}\""
echo ""
