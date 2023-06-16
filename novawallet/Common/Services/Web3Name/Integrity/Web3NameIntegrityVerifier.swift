import Foundation

protocol Web3NameIntegrityVerifierProtocol {
    func verify(serviceEndpointId: String, serviceEndpointContent: String) -> Bool
}

final class Web3NameIntegrityVerifier: Web3NameIntegrityVerifierProtocol {
    func verify(serviceEndpointId: String, serviceEndpointContent: String) -> Bool {
        guard let actualHash = try? serviceEndpointContent.data(using: .utf8)?.blake2b32() else {
            return false
        }

        let decodedExpectedHash = Data(multibaseEncoded: serviceEndpointId)

        return decodedExpectedHash == actualHash
    }
}
