import Foundation

enum AssertionDAppCallFactoryError: Error {
    case invalidAuthData
    case assertionUnsupported
}

struct AssertionVerificationDAppModel: Encodable {
    @Base64Codable var challenge: Data
    let appIntegrityId: AppAttestKeyId
    @Base64Codable var signature: AppAttestAssertion
    let platform: String = "iOS"
}

protocol AssertionDAppCallFactory {
    func createDAppResponse() throws -> DAppScriptResponse
}

extension AppAttestAssertionModelResult: AssertionDAppCallFactory {
    func createDAppResponse() throws -> DAppScriptResponse {
        guard case let .supported(appAttestAssertionModel) = self else {
            throw AssertionDAppCallFactoryError.assertionUnsupported
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
        else { throw AssertionDAppCallFactoryError.invalidAuthData }
        
        let content = String(
            format: "window.verifySignature(%@)",
            dataString
        )

        return DAppScriptResponse(content: content)
    }
}
