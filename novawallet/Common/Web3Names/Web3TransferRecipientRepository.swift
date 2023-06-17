import RobinHood

typealias Web3TransferRecipientResponse = [Caip19.AssetId: [Web3TransferRecipient]]

protocol Web3TransferRecipientRepositoryProtocol {
    func fetchRecipients(
        url: URL,
        hash: String?
    ) -> CompoundOperationWrapper<Web3TransferRecipientResponse>
}

enum KiltTransferAssetRecipient {
    enum Version1 {}
    enum Version2 {}
}

extension KiltTransferAssetRecipient.Version1 {
    typealias Response = [String: [Web3TransferRecipient]]

    final class Repository: GenericKiltTransferAssetRecipientRepository<Response> {
        init(
            integrityVerifier: Web3NameIntegrityVerifierProtocol,
            timeout: TimeInterval? = 60
        ) {
            super.init(integrityVerifier: integrityVerifier, timeout: timeout) { fetchResult in
                fetchResult.reduce(into: Web3TransferRecipientResponse()) { result, next in
                    if let assetId = try? Caip19.AssetId(raw: next.key) {
                        result[assetId] = next.value
                    }
                }
            }
        }
    }
}

extension KiltTransferAssetRecipient.Version2 {
    typealias Response = [String: [String: Account?]]
    struct Account: Decodable {
        let description: String?
    }

    final class Repository: GenericKiltTransferAssetRecipientRepository<Response> {
        init(
            integrityVerifier: Web3NameIntegrityVerifierProtocol,
            timeout: TimeInterval? = 60
        ) {
            super.init(integrityVerifier: integrityVerifier, timeout: timeout) { fetchResult in
                fetchResult.reduce(into: Web3TransferRecipientResponse()) { result, next in
                    if let assetId = try? Caip19.AssetId(raw: next.key) {
                        result[assetId] = next.value.map {
                            Web3TransferRecipient(account: $0.key, description: $0.value?.description)
                        }
                    }
                }
            }
        }
    }
}
