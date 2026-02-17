///| Discovery Document Unit Tests

///|
/// Test parsing valid discovery document with all fields
test "parse valid discovery document with all fields" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\",\"userinfo_endpoint\":\"https://example.com/userinfo\",\"scopes_supported\":[\"openid\",\"profile\",\"email\"],\"response_types_supported\":[\"code\",\"token\"],\"revocation_endpoint\":\"https://example.com/revoke\",\"introspection_endpoint\":\"https://example.com/introspect\",\"code_challenge_methods_supported\":[\"S256\",\"plain\"]}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => {
      assert_eq(doc.issuer, "https://example.com")
      assert_eq(doc.authorization_endpoint, "https://example.com/authorize")
      assert_eq(doc.token_endpoint, "https://example.com/token")
      assert_eq(doc.jwks_uri, "https://example.com/jwks")
      assert_eq(doc.userinfo_endpoint, Some("https://example.com/userinfo"))
      assert_false(doc.scopes_supported is None)
      assert_false(doc.response_types_supported is None)
      assert_eq(doc.revocation_endpoint, Some("https://example.com/revoke"))
      assert_eq(
        doc.introspection_endpoint,
        Some("https://example.com/introspect"),
      )
      assert_false(doc.code_challenge_methods_supported is None)
    }
    Err(e) => assert_false(true)
  }
}

///|
/// Test parsing valid discovery document with required fields only
test "parse valid discovery document with required fields only" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => {
      assert_eq(doc.issuer, "https://example.com")
      assert_eq(doc.authorization_endpoint, "https://example.com/authorize")
      assert_eq(doc.token_endpoint, "https://example.com/token")
      assert_eq(doc.jwks_uri, "https://example.com/jwks")
      assert_true(doc.userinfo_endpoint is None)
      assert_true(doc.scopes_supported is None)
      assert_true(doc.response_types_supported is None)
    }
    Err(e) => assert_false(true)
  }
}

///|
/// Test parsing fails with missing issuer
test "parse fails with missing issuer" {
  let json = "{\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("issuer"))
  }
}

///|
/// Test parsing fails with missing authorization_endpoint
test "parse fails with missing authorization_endpoint" {
  let json = "{\"issuer\":\"https://example.com\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("authorization_endpoint"))
  }
}

///|
/// Test parsing fails with missing token_endpoint
test "parse fails with missing token_endpoint" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("token_endpoint"))
  }
}

///|
/// Test parsing fails with missing jwks_uri
test "parse fails with missing jwks_uri" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("jwks_uri"))
  }
}

///|
/// Test parsing fails with invalid JSON
test "parse fails with invalid JSON" {
  let json = "not a valid json"

  let result = parse_discovery_document(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("parse"))
  }
}

///|
/// Test parsing fails with non-object JSON
test "parse fails with non-object JSON" {
  let json = "[\"array\",\"not\",\"object\"]"

  let result = parse_discovery_document(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("object"))
  }
}

///|
/// Test issuer getter
test "issuer returns correct value" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => assert_eq(doc.issuer(), "https://example.com")
    Err(e) => assert_false(true)
  }
}

///|
/// Test authorization_endpoint getter
test "authorization_endpoint returns correct value" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) =>
      assert_eq(doc.authorization_endpoint(), "https://example.com/authorize")
    Err(e) => assert_false(true)
  }
}

///|
/// Test token_endpoint getter
test "token_endpoint returns correct value" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => assert_eq(doc.token_endpoint(), "https://example.com/token")
    Err(e) => assert_false(true)
  }
}

///|
/// Test jwks_uri getter
test "jwks_uri returns correct value" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => assert_eq(doc.jwks_uri(), "https://example.com/jwks")
    Err(e) => assert_false(true)
  }
}

///|
/// Test optional field returns None when missing
test "optional field returns None when missing" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => {
      assert_true(doc.userinfo_endpoint() is None)
      assert_true(doc.scopes_supported() is None)
    }
    Err(e) => assert_false(true)
  }
}

///|
/// Test optional field returns Some when present
test "optional field returns Some when present" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\",\"userinfo_endpoint\":\"https://example.com/userinfo\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) =>
      assert_eq(doc.userinfo_endpoint(), Some("https://example.com/userinfo"))
    Err(e) => assert_false(true)
  }
}

///|
/// Test authorization_url creates AuthUrl correctly
test "authorization_url creates AuthUrl correctly" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => {
      let auth_url = doc.authorization_url()
      assert_eq(auth_url.to_string(), "https://example.com/authorize")
    }
    Err(e) => assert_false(true)
  }
}

///|
/// Test token_url creates TokenUrl correctly
test "token_url creates TokenUrl correctly" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => {
      let token_url = doc.token_url()
      assert_eq(token_url.to_string(), "https://example.com/token")
    }
    Err(e) => assert_false(true)
  }
}

///|
/// Test userinfo_url creates UserInfoUrl correctly
test "userinfo_url creates UserInfoUrl correctly" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\",\"userinfo_endpoint\":\"https://example.com/userinfo\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) =>
      match doc.userinfo_url() {
        Some(url) => assert_eq(url.to_string(), "https://example.com/userinfo")
        None => assert_false(true)
      }
    Err(e) => assert_false(true)
  }
}

///|
/// Test userinfo_url returns None when endpoint missing
test "userinfo_url returns None when endpoint missing" {
  let json = "{\"issuer\":\"https://example.com\",\"authorization_endpoint\":\"https://example.com/authorize\",\"token_endpoint\":\"https://example.com/token\",\"jwks_uri\":\"https://example.com/jwks\"}"

  let result = parse_discovery_document(json)
  match result {
    Ok(doc) => assert_true(doc.userinfo_url() is None)
    Err(e) => assert_false(true)
  }
}

///|
/// Test google_issuer_url returns correct URL
test "google_issuer_url returns correct URL" {
  assert_eq(google_issuer_url(), "https://accounts.google.com")
}
