import Foundation
import CryptoKit

enum NovaAuthFraming {
    static func registrationPreimage(appIdentity: NovaAuthAppIdentity, keyID: String) throws -> Data {
        try NovaAuthValidation.keyID(keyID)
        var result = Data("NOVA-REGISTRATION\0".utf8)
        result.append(contentsOf: [0, 3])
        for value in ["ios", appIdentity.appID, "app_attest", keyID, appIdentity.environment.rawValue] {
            result.append(try lengthPrefixed(value))
        }
        return result
    }

    static func issuancePreimage(origin: NovaAuthOrigin) throws -> Data {
        var result = Data("NOVA-TOKEN-ISSUANCE\0".utf8)
        result.append(contentsOf: [0, 3, 0, 1])
        result.append(try lengthPrefixed(origin.value))
        return result
    }

    // The protocol fixes these six independently framed inputs.
    // swiftlint:disable:next function_parameter_count
    static func clientDataHash(
        challenge: String,
        clientID: String,
        origin: NovaAuthOrigin,
        purpose: NovaAuthPurpose,
        contentType: String,
        bodyDigest: Data
    ) throws -> Data {
        Data(SHA256.hash(data: try preimage(
            challenge: challenge,
            clientID: clientID,
            origin: origin,
            purpose: purpose,
            contentType: contentType,
            bodyDigest: bodyDigest
        )))
    }

    // swiftlint:disable:next function_parameter_count
    static func preimage(
        challenge: String,
        clientID: String,
        origin: NovaAuthOrigin,
        purpose: NovaAuthPurpose,
        contentType: String,
        bodyDigest: Data
    ) throws -> Data {
        try NovaAuthValidation.challenge(challenge)
        try NovaAuthValidation.clientID(clientID)
        try NovaAuthValidation.contentType(contentType)
        guard bodyDigest.count == 32 else { throw NovaAuthError.invalidRequest }
        var result = Data("NOVA-ATTESTATION\0".utf8)
        result.append(contentsOf: [0, 3, purpose.byte])
        let authority = String(origin.value.dropFirst(8))
        let port = origin.url.port ?? 443
        for value in [challenge, clientID, "POST", "https", authority, String(port), purpose.path, contentType] {
            result.append(try lengthPrefixed(value))
        }
        result.append(bodyDigest)
        return result
    }

    private static func lengthPrefixed(_ value: String) throws -> Data {
        let bytes = Data(value.utf8)
        guard bytes.allSatisfy({ $0 < 128 }), let count = UInt32(exactly: bytes.count) else {
            throw NovaAuthError.invalidRequest
        }
        var bigEndian = count.bigEndian
        var result = withUnsafeBytes(of: &bigEndian) { Data($0) }
        result.append(bytes)
        return result
    }
}
