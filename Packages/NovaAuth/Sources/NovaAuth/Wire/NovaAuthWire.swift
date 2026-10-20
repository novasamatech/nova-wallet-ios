import Foundation

enum NovaAuthWire {
    static let contentType = "application/json"

    static func challengeBody(clientID: String, purpose: NovaAuthPurpose) throws -> Data {
        try NovaAuthValidation.clientID(clientID)
        return try encode(["profile": 3, "client_id": clientID,
                           "purpose": purpose == .registration ? "register" : "token"], limit: 1024)
    }

    static func registrationBody(_ request: NovaAuthRegistrationRequest) throws -> Data {
        try NovaAuthValidation.clientID(request.clientID)
        try NovaAuthValidation.challenge(request.challenge)
        try NovaAuthValidation.keyID(request.keyID)
        try NovaAuthValidation.contentType(request.contentType)
        guard !request.attestation.isEmpty,
              request.attestation.count <= 49152 else { throw NovaAuthError.invalidRequest }
        return try encode([
            "profile": 3, "client_id": request.clientID, "challenge": request.challenge,
            "platform": "ios", "app_id": request.appIdentity.appID, "attestation_type": "app_attest",
            "key_reference": request.keyID, "app_attest_environment": request.appIdentity.environment.rawValue,
            "integrity_token": request.attestation.base64EncodedString()
        ], limit: 98304)
    }

    static func tokenBody(_ request: NovaAuthTokenRequest) throws -> Data {
        try NovaAuthValidation.clientID(request.clientID)
        try NovaAuthValidation.challenge(request.challenge)
        try NovaAuthValidation.contentType(request.contentType)
        guard !request.assertion.isEmpty, request.assertion.count <= 6144 else { throw NovaAuthError.invalidRequest }
        return try encode([
            "profile": 3, "client_id": request.clientID, "challenge": request.challenge,
            "app_attest_assertion": request.assertion.base64EncodedString()
        ], limit: 16384)
    }

    static func decodeChallenge(_ response: NovaAuthResponse) throws -> NovaAuthChallenge {
        try requireStatus(200, response: response)
        let object = try NovaAuthJSON.parse(response.body, limit: 1024)
            .object(keys: ["challenge", "issued_at", "expires_at"])
        let challenge = try required(object, "challenge").string()
        let issuedAt = try required(object, "issued_at").unixSeconds()
        let expiresAt = try required(object, "expires_at").unixSeconds()
        try NovaAuthValidation.challenge(challenge)
        _ = try NovaAuthValidation.lifetime(issuedAt: issuedAt, expiresAt: expiresAt, range: 60 ... 60)
        return NovaAuthChallenge(challenge: challenge, issuedAt: issuedAt, expiresAt: expiresAt)
    }

    static func decodeToken(_ response: NovaAuthResponse) throws -> NovaAuthTokenResponse {
        try requireStatus(200, response: response)
        let object = try NovaAuthJSON.parse(response.body, limit: 8192)
            .object(keys: ["access_token", "token_type", "issued_at", "expires_at"])
        let token = try required(object, "access_token").string()
        guard try required(object, "token_type").string() == "Bearer" else { throw NovaAuthError.invalidResponse }
        let issuedAt = try required(object, "issued_at").unixSeconds()
        let expiresAt = try required(object, "expires_at").unixSeconds()
        try NovaAuthValidation.token(token)
        _ = try NovaAuthValidation.lifetime(issuedAt: issuedAt, expiresAt: expiresAt, range: 60 ... 900)
        return NovaAuthTokenResponse(accessToken: token, issuedAt: issuedAt, expiresAt: expiresAt)
    }

    static func decodeRegistration(_ response: NovaAuthResponse) throws {
        try requireStatus(204, response: response)
        guard response.body.isEmpty else { throw NovaAuthError.invalidResponse }
    }

    static func errorCode(from data: Data) -> String? {
        guard let root = try? NovaAuthJSON.parse(data, limit: 16384).object(keys: ["error"]),
              let error = try? root["error"]?.object(),
              let code = try? error["code"]?.string(),
              let message = try? error["message"]?.string(),
              (1 ... 256).contains(message.count), validCode(code) else { return nil }
        return code
    }

    static func serverError(_ response: NovaAuthResponse) -> NovaAuthServerError {
        NovaAuthServerError(
            statusCode: response.response.statusCode,
            code: errorCode(from: response.body),
            requestID: requestID(response.response),
            retryAfter: retryAfter(response.response)
        )
    }

    static func isGatewayRequestDefect(_ response: NovaAuthResponse) -> Bool {
        guard response.response.statusCode == 400, let code = errorCode(from: response.body) else { return false }
        return ["invalid_request", "invalid_target", "unsupported_profile"].contains(code)
    }

    static func requestID(_ response: HTTPURLResponse) -> String? {
        guard let value = response.value(forHTTPHeaderField: "X-Request-ID"),
              (1 ... 128).contains(value.utf8.count), value.utf8.allSatisfy({
                  (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57).contains($0) || [46, 95, 58, 45]
                      .contains($0)
              }) else { return nil }
        return value
    }

    static func retryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"), !value.isEmpty,
              value.utf8.count <= 10, value.utf8.allSatisfy({ (48 ... 57).contains($0) }),
              let seconds = UInt64(value) else { return nil }
        return min(TimeInterval(seconds), 905)
    }
}

private extension NovaAuthWire {
    static func encode(_ object: [String: Any], limit: Int) throws -> Data {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            guard data.count <= limit else { throw NovaAuthError.invalidRequest }
            return data
        } catch { throw NovaAuthError.invalidRequest }
    }

    static func requireStatus(_ status: Int, response: NovaAuthResponse) throws {
        guard response.response.statusCode == status else {
            if (200 ..< 300).contains(response.response.statusCode) { throw NovaAuthError.invalidResponse }
            throw NovaAuthError.bootstrap(serverError(response))
        }
    }

    static func required(_ object: [String: NovaAuthJSON], _ key: String) throws -> NovaAuthJSON {
        guard let value = object[key] else { throw NovaAuthError.invalidResponse }
        return value
    }

    static func validCode(_ code: String) -> Bool {
        guard (1 ... 64).contains(code.utf8.count), let first = code.utf8.first,
              (97 ... 122).contains(first) else { return false }
        return code.utf8.allSatisfy { (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 95 }
    }
}
