import Foundation
import Operation_iOS

final class SubtensorHistoryFiltersProvider {
    let chainAsset: ChainAsset
    let novaFeeBeneficiary: AccountId?

    init(
        chainAsset: ChainAsset,
        novaFeeBeneficiary: AccountId? = SubtensorNovaFeeCalculator.defaultBeneficiary
    ) {
        self.chainAsset = chainAsset
        self.novaFeeBeneficiary = novaFeeBeneficiary
    }
}

extension SubtensorHistoryFiltersProvider: TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        guard
            chainAsset.asset.hasSubtensorStaking,
            let accountPrefix = SubtensorStakingPallet.subnetAccountPrefix else {
            return .createWithResult([])
        }

        // stake movements transfer TAO between the coldkey and per-netuid subnet
        // accounts via Balances.Transfer, so those rows are suppressed to avoid
        // phantom sent/received entries next to the staking extrinsic itself
        let filter = TransactionHistoryAccountPrefixFilter(
            accountPrefix: accountPrefix,
            chainAsset: chainAsset
        )

        guard let novaFeeBeneficiary else {
            return .createWithResult([filter])
        }

        let novaFeeFilter = TransactionHistoryTransfersFilter(
            ignoredSenders: [],
            ignoredRecipients: [novaFeeBeneficiary],
            chainAsset: chainAsset
        )

        return .createWithResult([filter, novaFeeFilter])
    }
}
