protocol Web3TransferRecipientIntegrityVerifierFactoryProtocol {
    var knownServices: [String] { get }
    func createVerifier(for serviceName: String) -> Web3NameIntegrityVerifierProtocol
}

final class Web3TransferRecipientIntegrityVerifierFactory: Web3TransferRecipientIntegrityVerifierFactoryProtocol {
    var knownServices: [String] {
        [
            KnownServices.transferAssetRecipientV1,
            KnownServices.transferAssetRecipientV2
        ]
    }

    func createVerifier(for serviceName: String) -> Web3NameIntegrityVerifierProtocol {
        switch serviceName {
        case KnownServices.transferAssetRecipientV1:
            return Web3NameIntegrityVerifier()
        case KnownServices.transferAssetRecipientV2:
            return Web3NameIntegrityVerifierWithCanonicalizationData(jsonCanonicalizer: JsonCanonicalizer())
        default:
            assertionFailure("Integrity checker for service \(serviceName) is not resolved. Please use service from knownServices")
            return Web3NameIntegrityVerifier()
        }
    }
}
