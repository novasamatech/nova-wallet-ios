import RobinHood

typealias TransferAssetRecipientResponse = [Caip19.AssetId: [KiltTransferAssetRecipientAccount]]

protocol KiltTransferAssetRecipientRepositoryProtocol {
    func fetchRecipients(url: URL) -> CompoundOperationWrapper<TransferAssetRecipientResponse>
}

final class KiltTransferAssetRecipientRepository: JsonFileRepository<KiltTransferAssetRecipientResponse> {}

extension KiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol {
    func fetchRecipients(url: URL) -> CompoundOperationWrapper<TransferAssetRecipientResponse> {
        fetchAndMapOperation(
            by: url,
            defaultValue: [:]
        ) { fetchResult in
            fetchResult.reduce(into: TransferAssetRecipientResponse()) { result, next in
                if let assetId = try? Caip19.AssetId(raw: next.key) {
                    result[assetId] = next.value
                }
            }
        }
    }
}
