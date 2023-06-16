import Foundation

final class Web3NameIntegrityVerifierWithCanonicalizationData: Web3NameIntegrityVerifierProtocol {
    private let jsonCanonicalizer: JsonCanonicalizerProtocol

    init(jsonCanonicalizer: JsonCanonicalizerProtocol) {
        self.jsonCanonicalizer = jsonCanonicalizer
    }

    func verify(serviceEndpointId: String, serviceEndpointContent: String) -> Bool {
        guard let data = serviceEndpointContent.data(using: .utf8) else {
            return false
        }
        guard let canonicalizedJSON = try? jsonCanonicalizer.canonicalizeJSON(data),
              let canonicalizedData = canonicalizedJSON.data(using: .utf8) else {
            return false
        }

        guard let actualHash = try? canonicalizedData.blake2b32() else {
            return false
        }

        let decodedExpectedHash = Data(multibaseEncoded: serviceEndpointId)

        return decodedExpectedHash == actualHash
    }
}
