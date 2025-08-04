import Foundation

typealias AppAttestKeyId = String
typealias AppAttestResult = Data
typealias AppAttestAssertion = Data

struct AppAttestModel {
    let keyId: AppAttestKeyId
    let challenge: Data
    let result: AppAttestResult
}
