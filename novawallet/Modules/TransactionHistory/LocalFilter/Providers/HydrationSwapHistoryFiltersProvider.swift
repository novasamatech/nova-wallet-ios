import Foundation
import Operation_iOS

final class HydrationSwapHistoryFiltersProvider {
    let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }
}

private extension HydrationSwapHistoryFiltersProvider {
    typealias SystemAccounts = (senders: Set<AccountId>, recipients: Set<AccountId>)

    func createSystemAccounts() throws -> SystemAccounts {
        let accountIdSize = chainAsset.chain.accountIdSize

        let beneficiary = try AssetExchangeCommissionConstants.hydrationBeneficiaryAddress.toAccountId()
        let router = try HydraRouter.getPalletAccountId(for: accountIdSize)

        return (senders: [router], recipients: [beneficiary, router])
    }
}

extension HydrationSwapHistoryFiltersProvider: TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        guard chainAsset.chain.hasSwapHydra else {
            return .createWithResult([])
        }

        do {
            let systemAccounts = try createSystemAccounts()

            let filter = TransactionHistoryTransfersFilter(
                ignoredSenders: systemAccounts.senders,
                ignoredRecipients: systemAccounts.recipients,
                chainAsset: chainAsset
            )

            return .createWithResult([filter])
        } catch {
            return .createWithError(error)
        }
    }
}
