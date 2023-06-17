protocol Web3TransferRecipientRepositoryFactoryProtocol {
    var knownServices: [String] { get }
    func createRepository(for serviceName: String) -> Web3TransferRecipientRepositoryProtocol
}

final class Web3TransferRecipientRepositoryFactory: Web3TransferRecipientRepositoryFactoryProtocol {
    var knownServices: [String] {
        [
            KnownServices.transferAssetRecipientV1,
            KnownServices.transferAssetRecipientV2
        ]
    }

    let integrityVerifierFactory: Web3TransferRecipientIntegrityVerifierFactoryProtocol
    @Atomic(defaultValue: [:])
    private var cache: [String: Web3TransferRecipientRepositoryProtocol]

    init(integrityVerifierFactory: Web3TransferRecipientIntegrityVerifierFactoryProtocol) {
        self.integrityVerifierFactory = integrityVerifierFactory
    }

    func createRepository(for serviceName: String) -> Web3TransferRecipientRepositoryProtocol {
        if let service = cache[serviceName] {
            return service
        }
        switch serviceName {
        case KnownServices.transferAssetRecipientV1:
            let integrityVerifier = integrityVerifierFactory.createVerifier(for: serviceName)
            let service = KiltTransferAssetRecipient.Version1.Repository(integrityVerifier: integrityVerifier)
            cache[serviceName] = service
            return service
        case KnownServices.transferAssetRecipientV2:
            let integrityVerifier = integrityVerifierFactory.createVerifier(for: serviceName)
            let service = KiltTransferAssetRecipient.Version2.Repository(integrityVerifier: integrityVerifier)
            cache[serviceName] = service
            return service
        default:
            assertionFailure("Repository for service \(serviceName) is not resolved. Please use service from knownServices")
            let integrityVerifier = integrityVerifierFactory.createVerifier(for: serviceName)
            return KiltTransferAssetRecipient.Version1.Repository(integrityVerifier: integrityVerifier)
        }
    }

    func resetCache() {
        cache = [:]
    }
}
