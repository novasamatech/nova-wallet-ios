import Foundation
import BigInt
import SubstrateSdk

private typealias SyncResult = StorageListSyncResult<
    ParachainStaking.CollatorSnapshotKey, ParachainStaking.CollatorSnapshot
>

extension ParachainStakingCollatorService {
    private func updateCollators(
        roundInfo: ParachainStaking.RoundInfo,
        collatorCommission: BigUInt,
        result: SyncResult
    ) {
        guard roundInfo == self.roundInfo, collatorCommission == self.collatorCommission else {
            logger.warning("Collators fetched but parameters changed. Cancelled.")
            return
        }

        let collators: [CollatorInfo] = result.items.map { item in
            CollatorInfo(accountId: item.key.accountId, snapshot: item.value)
        }

        let snapshot = SelectedRoundCollators(
            round: roundInfo.current,
            commission: collatorCommission,
            collators: collators
        )

        didReceiveSnapshot(snapshot)
    }

    private func updateIfNeeded(
        roundInfo: ParachainStaking.RoundInfo,
        collatorCommission: BigUInt
    ) {
        guard roundInfo == self.roundInfo, collatorCommission == self.collatorCommission else {
            logger.warning("Prefix key for formed but parameters changed. Cancelled.")
            return
        }

        syncService?.throttle()

        syncService = StorageListSyncService(
            key: String(roundInfo.current),
            chainId: chainId,
            storagePath: ParachainStaking.atStakePath,
            repositoryFactory: SubstrateRepositoryFactory(storageFacade: storageFacade),
            connection: connection,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            logger: logger,
            completionQueue: syncQueue
        ) { [weak self] result in
            self?.updateCollators(
                roundInfo: roundInfo,
                collatorCommission: collatorCommission,
                result: result
            )
        }

        syncService?.setup()
    }

    func didUpdateRoundInfo(_ roundInfo: ParachainStaking.RoundInfo) {
        if let collatorCommission = self.collatorCommission {
            updateIfNeeded(roundInfo: roundInfo, collatorCommission: collatorCommission)
        }
    }

    func didUpdateCollatorCommission(_ collatorCommission: BigUInt) {
        if let roundInfo = self.roundInfo {
            updateIfNeeded(roundInfo: roundInfo, collatorCommission: collatorCommission)
        }
    }
}
