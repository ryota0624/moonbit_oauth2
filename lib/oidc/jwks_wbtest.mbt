///| JWKS Unit Tests

///|
/// Test parsing valid RSA JWK with all fields
test "parse valid RSA JWK with all fields" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"use\":\"sig\",\"alg\":\"RS256\",\"n\":\"0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys.length(), 1)
      let jwk = keys[0]
      assert_eq(jwk.kty, "RSA")
      assert_eq(jwk.kid, "key123")
      assert_eq(jwk.use_, Some("sig"))
      assert_eq(jwk.alg, Some("RS256"))
      assert_false(jwk.n is None)
      assert_false(jwk.e is None)
      assert_true(jwk.is_rsa())
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test parsing valid RSA JWK with required fields only
test "parse valid RSA JWK with required fields only" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"n\":\"test_modulus\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys.length(), 1)
      let jwk = keys[0]
      assert_eq(jwk.kty, "RSA")
      assert_eq(jwk.kid, "key123")
      assert_true(jwk.use_ is None)
      assert_true(jwk.alg is None)
      assert_eq(jwk.n, Some("test_modulus"))
      assert_eq(jwk.e, Some("AQAB"))
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test parsing JWK with optional use and alg
test "parse JWK with optional use and alg" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"use\":\"sig\",\"alg\":\"RS256\",\"n\":\"test\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      let jwk = keys[0]
      assert_eq(jwk.use_(), Some("sig"))
      assert_eq(jwk.alg(), Some("RS256"))
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test parsing fails with missing kty
test "parse fails with missing kty" {
  let json = "{\"keys\":[{\"kid\":\"key123\",\"n\":\"test_modulus\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) =>
      assert_true(
        e.message().contains("kty") || e.message().contains("No valid"),
      )
  }
}

///|
/// Test parsing fails with missing kid
test "parse fails with missing kid" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"n\":\"test_modulus\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) =>
      assert_true(
        e.message().contains("kid") || e.message().contains("No valid"),
      )
  }
}

///|
/// Test parsing RSA JWK fails with missing n
test "parse RSA JWK fails with missing n" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) =>
      assert_true(
        e.message().contains("'n'") || e.message().contains("No valid"),
      )
  }
}

///|
/// Test parsing RSA JWK fails with missing e
test "parse RSA JWK fails with missing e" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"n\":\"test_modulus\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) =>
      assert_true(
        e.message().contains("'e'") || e.message().contains("No valid"),
      )
  }
}

///|
/// Test parsing valid JWKSet with multiple keys
test "parse valid JWKSet with multiple keys" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\",\"n\":\"test1\",\"e\":\"AQAB\"},{\"kty\":\"RSA\",\"kid\":\"key2\",\"n\":\"test2\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys.length(), 2)
      assert_eq(keys[0].kid(), "key1")
      assert_eq(keys[1].kid(), "key2")
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test parsing valid JWKSet with single key
test "parse valid JWKSet with single key" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\",\"n\":\"test1\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys.length(), 1)
      assert_eq(keys[0].kid(), "key1")
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test parsing fails with missing keys array
test "parse fails with missing keys array" {
  let json = "{}"

  let result = parse_jwks(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("keys"))
  }
}

///|
/// Test parsing skips invalid JWKs in array
test "parse skips invalid JWKs in array" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\",\"n\":\"test1\",\"e\":\"AQAB\"},{\"kty\":\"RSA\",\"kid\":\"key2\"},{\"kty\":\"RSA\",\"kid\":\"key3\",\"n\":\"test3\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys.length(), 2)
      assert_eq(keys[0].kid(), "key1")
      assert_eq(keys[1].kid(), "key3")
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test find_by_kid returns correct key
test "find_by_kid returns correct key" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\",\"n\":\"test1\",\"e\":\"AQAB\"},{\"kty\":\"RSA\",\"kid\":\"key2\",\"n\":\"test2\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) =>
      match jwks.find_by_kid("key2") {
        Some(jwk) => assert_eq(jwk.kid(), "key2")
        None => assert_false(true)
      }
    Err(_) => assert_false(true)
  }
}

///|
/// Test find_by_kid returns None for non-existent kid
test "find_by_kid returns None for non-existent kid" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\",\"n\":\"test1\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => assert_true(jwks.find_by_kid("nonexistent") is None)
    Err(_) => assert_false(true)
  }
}

///|
/// Test find_rsa_key_by_kid returns RSA key
test "find_rsa_key_by_kid returns RSA key" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\",\"n\":\"test1\",\"e\":\"AQAB\"},{\"kty\":\"EC\",\"kid\":\"key2\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) =>
      match jwks.find_rsa_key_by_kid("key1") {
        Some(jwk) => {
          assert_eq(jwk.kid(), "key1")
          assert_true(jwk.is_rsa())
        }
        None => assert_false(true)
      }
    Err(_) => assert_false(true)
  }
}

///|
/// Test find_rsa_key_by_kid returns None for non-RSA key
test "find_rsa_key_by_kid returns None for non-RSA key" {
  let json = "{\"keys\":[{\"kty\":\"EC\",\"kid\":\"key1\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => assert_true(jwks.find_rsa_key_by_kid("key1") is None)
    Err(_) => assert_false(true)
  }
}

///|
/// Test get_all_keys returns all keys
test "get_all_keys returns all keys" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\",\"n\":\"test1\",\"e\":\"AQAB\"},{\"kty\":\"RSA\",\"kid\":\"key2\",\"n\":\"test2\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys.length(), 2)
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test is_rsa returns true for RSA key
test "is_rsa returns true for RSA key" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"n\":\"test\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_true(keys[0].is_rsa())
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test is_rsa returns false for non-RSA key
test "is_rsa returns false for non-RSA key" {
  let json = "{\"keys\":[{\"kty\":\"EC\",\"kid\":\"key123\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_false(keys[0].is_rsa())
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test is_ec returns true for EC key
test "is_ec returns true for EC key" {
  let json = "{\"keys\":[{\"kty\":\"EC\",\"kid\":\"key123\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_true(keys[0].is_ec())
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test is_ec returns false for non-EC key
test "is_ec returns false for non-EC key" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"n\":\"test\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_false(keys[0].is_ec())
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test rsa_modulus returns correct value
test "rsa_modulus returns correct value" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"n\":\"test_modulus\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys[0].rsa_modulus(), Some("test_modulus"))
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test rsa_exponent returns correct value
test "rsa_exponent returns correct value" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key123\",\"n\":\"test\",\"e\":\"AQAB\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(jwks) => {
      let keys = jwks.get_all_keys()
      assert_eq(keys[0].rsa_exponent(), Some("AQAB"))
    }
    Err(_) => assert_false(true)
  }
}

///|
/// Test parsing fails with all invalid JWKs
test "parse fails with all invalid JWKs" {
  let json = "{\"keys\":[{\"kty\":\"RSA\",\"kid\":\"key1\"},{\"kid\":\"key2\"}]}"

  let result = parse_jwks(json)
  match result {
    Ok(_) => assert_false(true)
    Err(e) => assert_true(e.message().contains("No valid JWKs"))
  }
}
