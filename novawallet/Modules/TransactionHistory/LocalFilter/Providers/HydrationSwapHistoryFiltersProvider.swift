import Foundation
import Operation_iOS

/// Hides the legs of a Hydration swap the user never asked for: the Nova commission transfer and
/// the user <-> Router transfers the pallet makes while the swap executes. Without this the
/// indexer surfaces them as ordinary outgoing/incoming transfers next to the swap entry.
///
/// Mirrors the Android client's `HydrationSwapTransferFilterFactory` so both platforms render the
/// same history for the same extrinsic.
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

        // the commission only ever leaves the user, whereas the router both takes and returns funds
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
