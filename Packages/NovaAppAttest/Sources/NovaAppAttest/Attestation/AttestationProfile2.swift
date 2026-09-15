import Foundation

/// Profile 2 requires this field order and framing. Pass the preimage to App Attest so
/// `clientDataHash` is exactly `SHA256(preimage)`.
public enum AttestationProfile2 {
    public static let version = 2

    public enum Purpose: UInt8 {
        case register = 0x01
        case request = 0x02

        /// Challenge envelopes use this string; the preimage uses `rawValue`.
        public var wireName: String {
            switch self {
            case .register: "register"
            case .request: "request"
            }
        }
    }

    /// Replaces the body digest for registration, whose body contains the resulting attestation token.
    public static func registrationDigest(
        platform: String,
        appId: String,
        attestationType: String,
        keyReference: String,
        appAttestEnvironment: String
    ) -> Data {
        var preimage = Data("NOVA-REGISTRATION\u{0}".utf8)

        preimage += bigEndian(UInt16(version))

        for field in [platform, appId, attestationType, keyReference, appAttestEnvironment] {
            preimage += lengthPrefixed(field)
        }

        return preimage.sha256()
    }

    /// Hash the exact request body; use empty data for a request without a body.
    public static func bodyDigest(_ body: Data) -> Data {
        body.sha256()
    }

    /// `bodyDigest` is `registrationDigest` for a registration and `bodyDigest(_:)` for a protected
    /// request.
    public static func preimage(
        purpose: Purpose,
        challenge: String,
        clientId: String,
        target: AttestationRequestTarget,
        bodyDigest: Data
    ) -> Data {
        var preimage = Data("NOVA-ATTESTATION\u{0}".utf8)

        preimage += bigEndian(UInt16(version))
        preimage.append(purpose.rawValue)

        let fields = [
            challenge,
            clientId,
            target.method,
            target.scheme,
            target.authority,
            target.port,
            target.path,
            target.contentType
        ]

        for field in fields {
            preimage += lengthPrefixed(field)
        }

        return preimage + bodyDigest
    }
}

// MARK: - Private

private extension AttestationProfile2 {
    // Lengths count UTF-8 bytes; validated fields fit within UInt32.
    static func lengthPrefixed(_ value: String) -> Data {
        let bytes = Data(value.utf8)

        return bigEndian(UInt32(bytes.count)) + bytes
    }

    static func bigEndian(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }

    static func bigEndian(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}
