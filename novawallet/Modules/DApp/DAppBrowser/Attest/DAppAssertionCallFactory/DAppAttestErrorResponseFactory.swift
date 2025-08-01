import Foundation

struct DAppAttestErrorResponseFactory {
    private let code: Int
    private let message: String?

    init(code: Int, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

extension DAppAttestErrorResponseFactory: DAppAssertionCallFactory {
    func createDAppResponse() throws -> DAppScriptResponse {
        let content =
            """
            window.verificationFailedOnClient({
                error: \(code),
                message: "\(message ?? "")"
            })
            """

        return DAppScriptResponse(content: content)
    }
}
