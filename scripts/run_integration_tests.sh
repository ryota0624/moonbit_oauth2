#!/bin/bash
# Integration test runner for OAuth2 client library
# This script starts the mock OAuth2 server and runs all tests

set -e

echo "🚀 Starting mock OAuth2 server..."
docker compose up -d mock-oauth2

echo "⏳ Waiting for server to be ready..."
sleep 5

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
echo "🧪 Running integration tests..."
moon test

TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo ""
    echo "✅ All tests passed!"
else
    echo ""
    echo "❌ Tests failed!"
fi

# Cleanup
echo ""
echo "🧹 Stopping mock OAuth2 server..."
docker compose down

exit $TEST_RESULT
