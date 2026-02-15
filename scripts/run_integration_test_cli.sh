#!/bin/bash
# Integration test CLI runner
# This script starts the mock OAuth2 server and runs the integration test CLI tool

set -e

echo "🚀 Starting mock OAuth2 server..."
docker compose up -d mock-oauth2

echo "⏳ Waiting for server to be ready..."
sleep 3

# Check if server is ready
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:8081/default/.well-known/openid-configuration > /dev/null 2>&1; then
        echo "✅ Mock OAuth2 server is ready!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "❌ Failed to start mock OAuth2 server"
        docker compose logs mock-oauth2
        docker compose down
        exit 1
    fi
    sleep 1
done

echo ""
echo "🧪 Running integration test CLI tool..."
echo ""
moon run lib/integration_test_cli

TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo ""
    echo "✅ Integration test completed!"
else
    echo ""
    echo "❌ Integration test failed!"
fi

# Cleanup
echo ""
echo "🧹 Stopping mock OAuth2 server..."
docker compose down

exit $TEST_RESULT
