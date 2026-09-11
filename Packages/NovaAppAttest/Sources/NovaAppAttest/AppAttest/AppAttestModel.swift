import Foundation

public typealias AppAttestKeyId = String
public typealias AppAttestAssertion = Data

public struct AppAttestAttestation {
    public let keyId: AppAttestKeyId
    public let attestation: Data

    public init(keyId: AppAttestKeyId, attestation: Data) {
        self.keyId = keyId
        self.attestation = attestation
    }
}
