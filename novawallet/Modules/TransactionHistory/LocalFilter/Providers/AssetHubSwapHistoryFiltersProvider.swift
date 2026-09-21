import Foundation
import Operation_iOS

final class AssetHubSwapHistoryFiltersProvider {
    let chainAsset: ChainAsset
    let beneficiaries: Set<AccountId>

    init(
        chainAsset: ChainAsset,
        beneficiaries: Set<AccountId>? = nil,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset

        if let beneficiaries {
            self.beneficiaries = beneficiaries
        } else {
            let resolved = AssetExchangeCommissionConstants.assetHubHistoryBeneficiaries(
                for: chainAsset.chain.chainId
            )

            resolved.invalid.forEach {
                logger.error("Invalid Asset Hub history beneficiary for \(chainAsset.chain.chainId): \($0)")
            }

            self.beneficiaries = resolved.accountIds
        }
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
