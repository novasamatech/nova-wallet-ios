import Foundation
import Operation_iOS

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

    final class Repository: BaseKiltTransferAssetRecipientRepository<Response> {
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

    final class Repository: BaseKiltTransferAssetRecipientRepository<Response> {
        init(
            integrityVerifier: Web3NameIntegrityVerifierProtocol,
            timeout: TimeInterval? = 60
        ) {
            super.init(integrityVerifier: integrityVerifier, timeout: timeout) { fetchResult in
                fetchResult.reduce(into: Web3TransferRecipientResponse()) { result, next in
                    if let assetId = try? Caip19.AssetId(raw: next.key) {
                        result[assetId] = next.value.map {
                            Web3TransferRecipient(account: $0.key, description: $0.value?.description)
                        }.sorted { item1, item2 in
                            let desc1 = item1.description ?? ""
                            let desc2 = item2.description ?? ""

                            if !desc1.isEmpty, !desc2.isEmpty {
                                return desc1.lexicographicallyPrecedes(desc2)
                            } else if !desc1.isEmpty {
                                return true
                            } else if !desc2.isEmpty {
                                return false
                            } else {
                                return item1.account.lexicographicallyPrecedes(item2.account)
                            }
                        }
                    }
                }
            }
        }
    }
}
