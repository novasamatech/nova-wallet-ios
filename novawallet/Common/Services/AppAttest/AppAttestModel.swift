import Foundation

typealias AppAttestKeyId = String
typealias AppAttestAssertion = Data

struct AppAttestAttestation {
    let keyId: AppAttestKeyId
    let attestation: Data
}
