protocol Web3NameIntegrityVerifierProtocol {
    func verify(serviceEndpointId: String, serviceEndpointContent: String) -> Bool
}

final class Web3NameIntegrityVerifier: Web3NameIntegrityVerifierProtocol {
    func verify(serviceEndpointId: String, serviceEndpointContent: String) -> Bool {
        guard let expectedHash = serviceEndpointId.split(by: .hashtag, maxSplits: 1)[safe: 1] else {
            return false
        }
        guard let actualHash = try? serviceEndpointContent.data(using: .utf8)?.blake2b32() else {
            return false
        }

        let decodedExpectedHash = decodeMultibase(expectedHash)

        return decodedExpectedHash == actualHash
    }
}
