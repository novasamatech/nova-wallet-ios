import Foundation

protocol ConfigMirrorAnswerValidating {
    /// Returns why a complete answer of the mirror can't be used or `nil` when it can.
    func validate(response: URLResponse?, data: Data, mirrorURL: URL) -> ConfigMirrorFailure?
}

/// Callers that receive raw data decode it when the request is over and it is too late to fall back,
/// so an answer of the mirror counts only if its body is usable.
struct ConfigMirrorAnswerValidator {}

extension ConfigMirrorAnswerValidator: ConfigMirrorAnswerValidating {
    func validate(response: URLResponse?, data: Data, mirrorURL: URL) -> ConfigMirrorFailure? {
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == Constants.successStatusCode else {
            return .unexpectedStatus((response as? HTTPURLResponse)?.statusCode)
        }

        // The page of a network on the way (a captive portal, a proxy) can come with 200 as well.
        // The content type is not compared: the contract of the mirror tells not to depend on it.
        guard httpResponse.value(forHTTPHeaderField: ConfigMirrorConstants.commitHeader)?.isEmpty == false else {
            return .missingCommitHeader
        }

        guard !data.isEmpty else {
            return .emptyBody
        }

        guard isJson(mirrorURL), (try? JSONSerialization.jsonObject(with: data)) == nil else {
            return nil
        }

        return .malformedJson
    }
}

// MARK: Private

private extension ConfigMirrorAnswerValidator {
    enum Constants {
        static let successStatusCode = 200
        static let jsonExtension = "json"
    }

    func isJson(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == Constants.jsonExtension
    }
}
