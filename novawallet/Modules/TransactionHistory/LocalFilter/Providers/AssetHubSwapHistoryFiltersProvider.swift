import Foundation
import Operation_iOS

final class AssetHubSwapHistoryFiltersProvider {
    let chainAsset: ChainAsset
    let beneficiaries: Set<AccountId>

    init(chainAsset: ChainAsset, logger: LoggerProtocol) {
        self.chainAsset = chainAsset

        beneficiaries = AssetExchangeCommissionConstants.assetHubHistoryBeneficiaries(
            for: chainAsset.chain.chainId,
            logger: logger,
            context: "history"
        )
    }
}

extension AssetHubSwapHistoryFiltersProvider: TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        guard chainAsset.chain.hasSwapHub else {
            return .createWithResult([])
        }

        let filter = TransactionHistoryTransfersFilter(
            ignoredSenders: [],
            ignoredRecipients: beneficiaries,
            chainAsset: chainAsset
        )

        return .createWithResult([filter])
    }
}
