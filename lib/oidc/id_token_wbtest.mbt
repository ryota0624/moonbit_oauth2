///| ID Token Verification Tests

///|
/// Test verify_claims succeeds with valid token
test "verify_claims succeeds with valid token" {
  let token_json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"test\",\"n\":\"test\",\"e\":\"AQAB\"}]}"
  let _jwks = match parse_jwks(token_json) {
    Ok(j) => j
    Err(_) => {
      assert_false(true)
      abort("Failed to parse JWKS")
    }
  }

  // Create a valid ID token (expires in future)
  let current_time = 1000000000L
  let exp_time = 2000000000L

  let claims : IdTokenClaims = {
    iss: "https://accounts.google.com",
    sub: "user123",
    aud: "my-client-id",
    exp: exp_time,
    iat: current_time,
    auth_time: None,
    nonce: Some("test-nonce"),
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: Some("test") }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  // Should succeed
  match
    token.verify_claims(
      "my-client-id",
      "https://accounts.google.com",
      current_time,
      Some("test-nonce"),
    ) {
    Ok(_) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}

///|
/// Test verify_claims fails with expired token
test "verify_claims fails with expired token" {
  let current_time = 2000000000L
  let exp_time = 1000000000L // Expired

  let claims : IdTokenClaims = {
    iss: "https://accounts.google.com",
    sub: "user123",
    aud: "my-client-id",
    exp: exp_time,
    iat: 900000000L,
    auth_time: None,
    nonce: None,
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: None }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  match
    token.verify_claims(
      "my-client-id",
      "https://accounts.google.com",
      current_time,
      None,
    ) {
    Ok(_) => assert_false(true)
    Err(TokenExpired(_, _)) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}

///|
/// Test verify_claims fails with invalid audience
test "verify_claims fails with invalid audience" {
  let current_time = 1000000000L

  let claims : IdTokenClaims = {
    iss: "https://accounts.google.com",
    sub: "user123",
    aud: "wrong-client-id",
    exp: 2000000000L,
    iat: current_time,
    auth_time: None,
    nonce: None,
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: None }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  match
    token.verify_claims(
      "my-client-id",
      "https://accounts.google.com",
      current_time,
      None,
    ) {
    Ok(_) => assert_false(true)
    Err(InvalidAudience(_, _)) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}

///|
/// Test verify_claims fails with invalid issuer
test "verify_claims fails with invalid issuer" {
  let current_time = 1000000000L

  let claims : IdTokenClaims = {
    iss: "https://wrong-issuer.com",
    sub: "user123",
    aud: "my-client-id",
    exp: 2000000000L,
    iat: current_time,
    auth_time: None,
    nonce: None,
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: None }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  match
    token.verify_claims(
      "my-client-id",
      "https://accounts.google.com",
      current_time,
      None,
    ) {
    Ok(_) => assert_false(true)
    Err(InvalidIssuer(_, _)) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}

///|
/// Test verify_claims succeeds without nonce
test "verify_claims succeeds without nonce" {
  let current_time = 1000000000L

  let claims : IdTokenClaims = {
    iss: "https://accounts.google.com",
    sub: "user123",
    aud: "my-client-id",
    exp: 2000000000L,
    iat: current_time,
    auth_time: None,
    nonce: None,
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: None }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  match
    token.verify_claims(
      "my-client-id",
      "https://accounts.google.com",
      current_time,
      None,
    ) {
    Ok(_) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}

///|
/// Test verify_claims fails with mismatching nonce
test "verify_claims fails with mismatching nonce" {
  let current_time = 1000000000L

  let claims : IdTokenClaims = {
    iss: "https://accounts.google.com",
    sub: "user123",
    aud: "my-client-id",
    exp: 2000000000L,
    iat: current_time,
    auth_time: None,
    nonce: Some("actual-nonce"),
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: None }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  match
    token.verify_claims(
      "my-client-id",
      "https://accounts.google.com",
      current_time,
      Some("expected-nonce"),
    ) {
    Ok(_) => assert_false(true)
    Err(InvalidNonce(_, _)) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}

///|
/// Test verify_claims fails with missing nonce when expected
test "verify_claims fails with missing nonce when expected" {
  let current_time = 1000000000L

  let claims : IdTokenClaims = {
    iss: "https://accounts.google.com",
    sub: "user123",
    aud: "my-client-id",
    exp: 2000000000L,
    iat: current_time,
    auth_time: None,
    nonce: None,
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: None }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  match
    token.verify_claims(
      "my-client-id",
      "https://accounts.google.com",
      current_time,
      Some("expected-nonce"),
    ) {
    Ok(_) => assert_false(true)
    Err(MissingNonce) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}

///|
/// Test verify_signature returns not implemented error
test "verify_signature returns not implemented error" {
  let token_json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"test\",\"n\":\"test\",\"e\":\"AQAB\"}]}"
  let jwks = match parse_jwks(token_json) {
    Ok(j) => j
    Err(_) => {
      assert_false(true)
      abort("Failed to parse JWKS")
    }
  }

  let claims : IdTokenClaims = {
    iss: "https://accounts.google.com",
    sub: "user123",
    aud: "my-client-id",
    exp: 2000000000L,
    iat: 1000000000L,
    auth_time: None,
    nonce: None,
    name: None,
    given_name: None,
    family_name: None,
    email: None,
    email_verified: None,
    picture: None,
    locale: None,
  }

  let header : JwtHeader = { alg: "RS256", typ: "JWT", kid: Some("test") }

  let token : IdToken = {
    raw: "header.payload.signature",
    header,
    payload: claims,
    signature: "sig",
  }

  match token.verify_signature(jwks) {
    Ok(_) => assert_false(true)
    Err(SignatureVerificationNotImplemented) => ()
    Err(e) => {
      println("Unexpected error: \{e.message()}")
      assert_false(true)
    }
  }
}
