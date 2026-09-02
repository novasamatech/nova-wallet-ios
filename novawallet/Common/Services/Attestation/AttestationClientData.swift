import Foundation

/// Byte-for-byte Android's AttestationSigning
/// (infrastructure/src/main/java/io/novafoundation/nova/infrastructure/attestation/AttestationSigning.kt:12-27,
/// PR #2324 head 108899870). AppAttestService hashes these with SHA-256, giving exactly
/// Android's signingPayload and attestationPayload.
enum AttestationClientData {
    static func bodyDigestHex(_ body: Data) -> String {
        body.sha256().map { String(format: "%02x", $0) }.joined()
    }

    static func assertionClientData(challenge: String, clientId: String, body: Data) -> Data {
        Data((challenge + clientId + bodyDigestHex(body)).utf8)
    }

    static func attestationClientData(challenge: String, clientId: String, keyId: String) -> Data {
        Data((challenge + clientId + keyId).utf8)
    }
}
