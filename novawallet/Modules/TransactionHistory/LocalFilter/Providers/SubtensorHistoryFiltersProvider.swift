import Foundation
import Operation_iOS

final class SubtensorHistoryFiltersProvider {
    let chainAsset: ChainAsset
    let logger: LoggerProtocol

    init(chainAsset: ChainAsset, logger: LoggerProtocol) {
        self.chainAsset = chainAsset
        self.logger = logger
    }
}

private extension SubtensorHistoryFiltersProvider {
    func resolveNovaFeeBeneficiaries() -> Set<AccountId> {
        let resolved = AssetExchangeCommissionConstants.historyBeneficiaries(
            current: [SubtensorNovaFeeConstants.beneficiaryAddress],
            historical: SubtensorNovaFeeConstants.historicalBeneficiaryAddresses
        )

        resolved.invalid.forEach {
            logger.error("Invalid Subtensor nova fee history beneficiary: \($0)")
        }

        return resolved.accountIds
    }
}

extension SubtensorHistoryFiltersProvider: TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        guard
            chainAsset.asset.hasSubtensorStaking,
            let accountPrefix = SubtensorStakingPallet.subnetAccountPrefix else {
            return .createWithResult([])
        }

        let subnetAccountsFilter = TransactionHistoryAccountPrefixFilter(
            accountPrefix: accountPrefix,
            ignoresOnlyWithinExtrinsic: true,
            chainAsset: chainAsset
        )

        let novaFeeFilter = TransactionHistoryTransfersFilter(
            ignoredSenders: [],
            ignoredRecipients: resolveNovaFeeBeneficiaries(),
            ignoresOnlySuccessful: true,
            chainAsset: chainAsset
        )

        return .createWithResult([subnetAccountsFilter, novaFeeFilter])
    }
}
