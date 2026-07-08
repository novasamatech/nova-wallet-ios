import Foundation
import BigInt
import Operation_iOS

/// Queries Bittensor chain storage (via the shared `SubtensorPositionCache`)
/// to compute the user's stake for a *single* netuid and persists it to the
/// multistaking dashboard repository.
///
/// One service instance exists per (ChainAsset, StakingType=.subtensor):
///   - The TAO asset (netuid=0) → one row showing root-network TAO stake.
///   - Each subnet alpha asset (netuid=1…128) → one row showing that subnet's
///     alpha holdings.
///
/// The netuid comes from the ChainAsset's `typeExtras.netuid` (set in nova-utils);
/// if missing, we assume 0 (root) for backward compatibility with the bare TAO
/// asset that carries no extras.
///
/// Because 129 of these services fire on wallet select (1 TAO + 128 subnets),
/// they share a single RPC fetch via `SubtensorPositionCache` — the first one
/// to call `positions(for:rpcURL:)` triggers the batched on-chain read and
/// the remaining 128 await its cached result, avoiding endpoint rate limiting.
final class SubtensorMultistakingUpdateService: ObservableSyncService {
    let walletId: MetaAccountModel.Id
    let accountId: AccountId
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let netuid: UInt16
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>
    let operationQueue: OperationQueue

    private let rpcURL: URL
    private var fetchTask: Task<Void, Never>?
    private var invalidationObserver: NSObjectProtocol?

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        netuid: UInt16,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemSubtensorPart>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.walletId = walletId
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.netuid = netuid
        self.dashboardRepository = dashboardRepository
        self.operationQueue = operationQueue

        let nodeURL = chainAsset.chain.nodes
            .compactMap { URL(string: $0.url) }
            .filter { $0.scheme == "https" || $0.scheme == "http" }
            .first ?? URL(string: "https://entrypoint-finney.opentensor.ai")!
        rpcURL = nodeURL

        super.init(logger: logger)

        // Wake up immediately when the cache is invalidated for our coldkey
        // (e.g. right after a stake/unstake `inBlock`) instead of waiting up
        // to 30s for the next scheduled poll. Pass `ignoreIfSyncing: false`
        // so a 30s poll that happened to be mid-fetch when the user's
        // `inBlock` lands gets cancelled and restarted; otherwise the in-
        // flight task would persist its pre-unstake snapshot to the
        // dashboard and the next refresh wouldn't run until 30s later.
        invalidationObserver = NotificationCenter.default.addObserver(
            forName: .subtensorPositionsInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let coldkey = notification.userInfo?["coldkey"] as? AccountId else { return }
            guard coldkey == self.accountId else { return }
            self.syncUp(afterDelay: 0, ignoreIfSyncing: false)
        }
    }

    deinit {
        if let invalidationObserver {
            NotificationCenter.default.removeObserver(invalidationObserver)
        }
    }

    // MARK: - ObservableSyncService

    /// How often to re-sync per service while the dashboard is active. BaseSyncService
    /// only runs `performSyncUp` once on `setup()`; we need periodic polling so the UI
    /// catches new stake/unstake activity without a wallet switch. Thanks to
    /// `SubtensorPositionCache`, 129 services sharing the same cycle still produce
    /// only 1 RPC fetch per interval per coldkey.
    private static let resyncInterval: TimeInterval = 30

    override func performSyncUp() {
        guard fetchTask == nil else { return }
        markSyncingImmediate()

        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let positions = try await SubtensorPositionCache.shared.positions(
                    for: self.accountId,
                    rpcURL: self.rpcURL
                )
                let total = positions
                    .filter { $0.netuid == self.netuid }
                    .reduce(BigUInt.zero) { $0 + $1.amount }
                try await self.persist(totalStake: total)
                self.fetchTask = nil
                self.completeImmediate(nil)
                // Schedule next poll; syncUp(afterDelay:) is a no-op if the
                // service was throttled in the meantime.
                self.syncUp(afterDelay: Self.resyncInterval, ignoreIfSyncing: true)
            } catch {
                guard !Task.isCancelled else { return }
                self.fetchTask = nil
                self.completeImmediate(error)
            }
        }
    }

    override func stopSyncUp() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    // MARK: - Persist

    private func persist(totalStake: BigUInt) async throws {
        let option = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )
        let item = Multistaking.DashboardItemSubtensorPart(
            stakingOption: option,
            state: .init(totalStake: totalStake)
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let saveOp = dashboardRepository.saveOperation({ [item] }, { [] })
            saveOp.completionBlock = {
                switch saveOp.result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                case .none:
                    continuation.resume()
                }
            }
            operationQueue.addOperation(saveOp)
        }
    }
}
