import Foundation

/// Client-data payloads hashed into App Attest challenges, byte-identical to Android's.
public enum AttestationClientData {
    public static func bodyDigestHex(_ body: Data) -> String {
        body.sha256().map { String(format: "%02x", $0) }.joined()
    }

    public static func assertionClientData(challenge: String, clientId: String, body: Data) -> Data {
        Data((challenge + clientId + bodyDigestHex(body)).utf8)
    }

    public static func attestationClientData(challenge: String, clientId: String, keyId: String) -> Data {
        Data((challenge + clientId + keyId).utf8)
    }
}
