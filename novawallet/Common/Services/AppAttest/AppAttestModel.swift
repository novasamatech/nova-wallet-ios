import Foundation

typealias AppAttestKeyId = String
typealias AppAttestResult = Data
typealias AppAttestAssertion = Data

struct AppAttestModel {
    let keyId: AppAttestKeyId
    let challenge: Data
    let result: AppAttestResult
}

enum AppAttestAssertionModelResult {
    case supported(AppAttestAssertionModel)
    case unsupported(bodyData: Data?)
}

struct AppAttestAssertionModel {
    let keyId: AppAttestKeyId
    let challenge: Data
    let assertion: AppAttestAssertion
    let bodyData: Data?
    let bundleId: String
}
