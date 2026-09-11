import Foundation

/// The exact bytes crypto profile 2 commits to.
///
/// The gateway rebuilds this preimage from the request it receives and compares its digest against
/// the one App Attest signed, so the field list, its order and its framing are contract rather than
/// convention. Callers hand the preimage to App Attest, which hashes it: the `clientDataHash` Apple
/// receives is `SHA256(preimage)`, never the preimage itself and never a second hash of the digest.
///
/// Pinned by `profile-2-vectors.json` in the gateway contract.
public enum AttestationProfile2 {
    public static let version = 2

    public enum Purpose: UInt8 {
        case register = 0x01
        case request = 0x02

        /// The spelling the challenge envelope carries; the byte above is what the preimage carries.
        public var wireName: String {
            switch self {
            case .register: "register"
            case .request: "request"
            }
        }
    }

    /// Stands in for the body digest of a registration, whose HTTP body cannot bind itself: it
    /// carries the provider token that the binding is supposed to authenticate.
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

    /// The digest a protected request commits to: `SHA256` of the frozen entity bytes, and of zero
    /// bytes when there is no body.
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
    /// `U32(byte count) || UTF-8`. Lengths count bytes, never characters; every field the contract
    /// frames this way is bounded well below `UInt32` by the target and envelope validators.
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
