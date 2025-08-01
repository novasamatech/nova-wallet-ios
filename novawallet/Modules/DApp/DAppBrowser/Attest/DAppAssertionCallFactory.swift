import Foundation

protocol DAppAssertionCallFactory {
    func createDAppResponse() throws -> DAppScriptResponse
}

enum AppAttestAssertionModelResult {
    case supported(AppAttestAssertionModel)
    case unsupported
}

struct AppAttestAssertionModel {
    let keyId: AppAttestKeyId
    let challenge: Data
    let assertion: AppAttestAssertion
    let bodyData: Data?
    let bundleId: String
}

extension AppAttestAssertionModelResult: DAppAssertionCallFactory {
    func createDAppResponse() throws -> DAppScriptResponse {
        guard case let .supported(appAttestAssertionModel) = self else {
            throw DAppAssertionCallFactoryError.assertionUnsupported
        }

        let verificationModel = AssertionVerificationDAppModel(
            challenge: appAttestAssertionModel.challenge,
            appIntegrityId: appAttestAssertionModel.keyId,
            signature: appAttestAssertionModel.assertion
        )

        let encoder = JSONEncoder()

        let jsonData = try? encoder.encode(verificationModel)

        guard
            let jsonData,
            let dataString = String(data: jsonData, encoding: .utf8)
        else { throw DAppAssertionCallFactoryError.invalidAuthData }

        let content = String(
            format: "window.verifySignature(%@)",
            dataString
        )

        return DAppScriptResponse(content: content)
    }
}

private struct AssertionVerificationDAppModel: Encodable {
    @Base64Codable var challenge: Data
    let appIntegrityId: AppAttestKeyId
    @Base64Codable var signature: AppAttestAssertion
    let platform: String = "iOS"
}

enum DAppAssertionCallFactoryError: Error {
    case invalidAuthData
    case assertionUnsupported
}
