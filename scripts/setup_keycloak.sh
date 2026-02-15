#!/bin/bash
set -e

# Keycloak セットアップスクリプト
# 使用方法: ./scripts/setup_keycloak.sh

echo "========================================="
echo "Keycloak セットアップスクリプト"
echo "========================================="
echo ""

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Keycloak と PostgreSQL を起動
echo -e "${YELLOW}[1/5] Keycloak と PostgreSQL を起動中...${NC}"
docker compose up -d keycloak postgres

# 起動待機
echo -e "${YELLOW}[2/5] Keycloak の起動を待機中（約30秒）...${NC}"
sleep 5

MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8080/health/ready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Keycloak が起動しました${NC}"
        break
    fi
    echo -n "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}✗ Keycloak の起動がタイムアウトしました${NC}"
    echo "ログを確認してください: docker compose logs keycloak"
    exit 1
fi

echo ""
echo -e "${YELLOW}[3/5] 管理者トークンを取得中...${NC}"

# 管理者としてログイン
ADMIN_TOKEN=$(curl -s -X POST 'http://localhost:8080/realms/master/protocol/openid-connect/token' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'username=admin' \
    -d 'password=admin' \
    -d 'grant_type=password' \
    -d 'client_id=admin-cli' | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    echo -e "${RED}✗ 管理者トークンの取得に失敗しました${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 管理者トークンを取得しました${NC}"

echo ""
echo -e "${YELLOW}[4/5] test-realm を作成中...${NC}"

# Realm の存在確認
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    'http://localhost:8080/admin/realms/test-realm')

if [ "$REALM_EXISTS" = "200" ]; then
    echo -e "${YELLOW}⚠ test-realm は既に存在します（スキップ）${NC}"
else
    # Realm の作成
    curl -s -X POST 'http://localhost:8080/admin/realms' \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d '{
            "realm": "test-realm",
            "enabled": true,
            "displayName": "Test Realm",
            "displayNameHtml": "<b>Test Realm</b>"
        }' > /dev/null

    echo -e "${GREEN}✓ test-realm を作成しました${NC}"
fi

echo ""
echo -e "${YELLOW}[5/5] test-client を作成中...${NC}"

# Client の存在確認
CLIENT_ID="test-client"
CLIENT_EXISTS=$(curl -s -X GET \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:8080/admin/realms/test-realm/clients?clientId=${CLIENT_ID}" | jq -r '.[0].id // empty')

if [ -n "$CLIENT_EXISTS" ]; then
    echo -e "${YELLOW}⚠ test-client は既に存在します（スキップ）${NC}"
else
    # Client の作成
    curl -s -X POST 'http://localhost:8080/admin/realms/test-realm/clients' \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d '{
            "clientId": "test-client",
            "enabled": true,
            "protocol": "openid-connect",
            "publicClient": false,
            "serviceAccountsEnabled": true,
            "directAccessGrantsEnabled": true,
            "standardFlowEnabled": true,
            "redirectUris": ["http://localhost:3000/callback"],
            "webOrigins": ["http://localhost:3000"],
            "attributes": {
                "pkce.code.challenge.method": "S256"
            }
        }' > /dev/null

    echo -e "${GREEN}✓ test-client を作成しました${NC}"
fi

# Client Secret を取得
sleep 2
CLIENT_UUID=$(curl -s -X GET \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:8080/admin/realms/test-realm/clients?clientId=${CLIENT_ID}" | jq -r '.[0].id')

CLIENT_SECRET=$(curl -s -X GET \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:8080/admin/realms/test-realm/clients/${CLIENT_UUID}/client-secret" | jq -r '.value')

echo ""
echo -e "${YELLOW}[6/7] testuser を作成中...${NC}"

# User の存在確認
USER_EXISTS=$(curl -s -X GET \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "http://localhost:8080/admin/realms/test-realm/users?username=testuser" | jq -r '.[0].id // empty')

if [ -n "$USER_EXISTS" ]; then
    echo -e "${YELLOW}⚠ testuser は既に存在します（スキップ）${NC}"
else
    # User の作成
    curl -s -X POST 'http://localhost:8080/admin/realms/test-realm/users' \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d '{
            "username": "testuser",
            "enabled": true,
            "email": "testuser@example.com",
            "emailVerified": true,
            "firstName": "Test",
            "lastName": "User",
            "credentials": [{
                "type": "password",
                "value": "testpass123",
                "temporary": false
            }]
        }' > /dev/null

    echo -e "${GREEN}✓ testuser を作成しました${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}セットアップ完了！${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "📋 認証情報:"
echo ""
echo "  管理コンソール: http://localhost:8080/admin"
echo "  - Username: admin"
echo "  - Password: admin"
echo ""
echo "  Realm: test-realm"
echo ""
echo "  Client ID: test-client"
echo "  Client Secret: ${CLIENT_SECRET}"
echo ""
echo "  Test User:"
echo "  - Username: testuser"
echo "  - Password: testpass123"
echo ""
echo "🔗 エンドポイント:"
echo ""
echo "  Token Endpoint:"
echo "    http://localhost:8080/realms/test-realm/protocol/openid-connect/token"
echo ""
echo "  Authorization Endpoint:"
echo "    http://localhost:8080/realms/test-realm/protocol/openid-connect/auth"
echo ""
echo "  UserInfo Endpoint:"
echo "    http://localhost:8080/realms/test-realm/protocol/openid-connect/userinfo"
echo ""
echo "🧪 テスト実行:"
echo ""
echo "  export CLIENT_ID=\"test-client\""
echo "  export CLIENT_SECRET=\"${CLIENT_SECRET}\""
echo "  export TOKEN_ENDPOINT=\"http://localhost:8080/realms/test-realm/protocol/openid-connect/token\""
echo ""
echo "  # Client Credentials Flow"
echo "  curl -X POST \"\${TOKEN_ENDPOINT}\" \\"
echo "    -H \"Content-Type: application/x-www-form-urlencoded\" \\"
echo "    -d \"grant_type=client_credentials\" \\"
echo "    -d \"client_id=\${CLIENT_ID}\" \\"
echo "    -d \"client_secret=\${CLIENT_SECRET}\" \\"
echo "    -d \"scope=openid\" | jq"
echo ""
echo "📖 詳細な手順は docs/testing/keycloak_verification_guide.md を参照してください"
echo ""
