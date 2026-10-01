import Foundation
import Cuckoo
import Operation_iOS
import SubstrateSdk
import XCTest
@testable import novawallet

enum SubtensorFlowActiveStake {
    typealias World = BittensorApiFixtureWorld

    static let rootStake: Balance = 20_000_000_000
    static let chutesAlpha: Balance = 70_200_000_000
    static let chutesLockedAlpha: Balance = 14_000_000_000
    static let chutesSpotPrice: Balance = 73_800_000
    static let targonAlpha: Balance = 88_000_000_000
    static let lastRootStakeBlock: UInt64 = 9_139_000
    static let existentialDeposit: Balance = 500
    static let chartEnd: UInt64 = 1_790_208_000_000

    static func state() throws -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                try position(.aster, netuid: World.rootNetuid, stake: rootStake),
                try position(.ember, netuid: 64, stake: chutesAlpha),
                try position(.cinder, netuid: 4, stake: targonAlpha)
            ],
            prices: [64: chutesSpotPrice, 4: 29_545_454],
            availability: [
                World.rootNetuid: availability(total: rootStake, locked: 0),
                64: availability(total: chutesAlpha, locked: chutesLockedAlpha),
                4: availability(total: targonAlpha, locked: 0)
            ]
        )
    }

    static func subnetsInfo() throws -> SubtensorSubnetsInfo {
        try SubtensorFlowChainWorld.subnetsInfo(overridingPrices: [64: chutesSpotPrice])
    }

    static func rootOnlyState() throws -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [try position(.aster, netuid: World.rootNetuid, stake: rootStake)],
            prices: [:],
            availability: [World.rootNetuid: availability(total: rootStake, locked: 0)]
        )
    }

    static func chutesGroupState() throws -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                try position(.ember, netuid: 64, stake: 50_000_000_000),
                try position(.cinder, netuid: 64, stake: 20_000_000_000)
            ],
            prices: [64: chutesSpotPrice],
            availability: [64: availability(total: 70_000_000_000, locked: 0)]
        )
    }

    static func claimPreviews() throws -> [SubtensorStakingPallet.BasketClaimPreview] {
        [
            try claimPreview(.aster, accrued: 431_000_000, redeemable: 420_000_000, forfeited: 11_000_000),
            try claimPreview(.blueHarbor, accrued: 300_000, redeemable: 300_000, forfeited: 0)
        ]
    }

    static func expectedClaimable() throws -> SubtensorRootClaimable {
        SubtensorRootClaimable(previews: [
            SubtensorRootClaimPreview(
                hotkey: try SubtensorFlowChainWorld.hotkey(.aster),
                accrued: 431_000_000,
                redeemable: 420_000_000,
                forfeitedEstimate: 11_000_000
            ),
            SubtensorRootClaimPreview(
                hotkey: try SubtensorFlowChainWorld.hotkey(.blueHarbor),
                accrued: 300_000,
                redeemable: 300_000,
                forfeitedEstimate: 0
            )
        ])
    }

    static func preflight(hotkeyOf member: World.Member, netuid: UInt16) throws -> SubtensorStakingPreflight {
        let validator = World.validator(member)

        return SubtensorStakingPreflight(
            hotkeyExists: true,
            subnetExists: true,
            subtokenEnabled: true,
            hasColdkeySwapAnnouncement: false,
            isSafeModeActive: false,
            stakeAvailability: nil,
            rootStakeUnlockInterval: 0,
            lastStakeBlock: netuid == World.rootNetuid ? lastRootStakeBlock : nil,
            minStake: 2_000_000,
            effectiveNominatorMinStake: 20_000_000,
            rootClaimableThreshold: SubtensorStakingPallet.defaultRootClaimableThreshold,
            delegateTake: validator.take,
            hotkeyOwner: try validator.coldkey.toAccountId(using: .substrate(SubstrateConstants.genericAddressPrefix))
        )
    }

    static func serveCharts() throws {
        let chutesStart = try SubtensorFlowLiteral.decimal("19.02")
        let chutesEnd = try SubtensorFlowLiteral.decimal("25.2396")

        serveCharts(coinId: "bittensor", start: 300, end: 342)
        serveCharts(coinId: "chutes", start: chutesStart, end: chutesEnd)
        SubtensorFlowURLProtocol.serveSubnetMarkets(chutesWeekStart: chutesStart, end: chutesEnd)
    }

    static func chartDate(daysBeforeEnd days: UInt64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(chartEnd - days * 86_400_000) / 1000)
    }
}

private extension SubtensorFlowActiveStake {
    static func position(
        _ member: World.Member,
        netuid: UInt16,
        stake: Balance
    ) throws -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: try SubtensorFlowChainWorld.hotkey(member),
            netuid: netuid,
            stakeAlpha: stake,
            hotkeyEmissionPerTempo: 0,
            totalHotkeyAlpha: nil,
            isRegistered: true
        )
    }

    static func availability(total: Balance, locked: Balance) -> SubtensorStakingPallet.StakeAvailability {
        SubtensorStakingPallet.StakeAvailability(total: total, locked: locked, available: total - locked)
    }

    static func claimPreview(
        _ member: World.Member,
        accrued: Balance,
        redeemable: Balance,
        forfeited: Balance
    ) throws -> SubtensorStakingPallet.BasketClaimPreview {
        SubtensorStakingPallet.BasketClaimPreview(
            hotkey: try SubtensorFlowChainWorld.hotkey(member),
            owedShares: 1_000_000,
            accruedTao: accrued,
            redeemableTao: redeemable,
            forfeitedTaoEst: forfeited,
            rows: 120,
            rowsToSell: 20,
            dustRows: 100,
            swept: 0,
            flushedCredits: 3
        )
    }

    static func serveCharts(coinId: String, start: Decimal, end: Decimal) {
        for days: UInt64 in [7, 30] {
            SubtensorFlowURLProtocol.serveMarketChart(coinId: coinId, days: "\(days)", points: [
                SubtensorFlowPricePoint(milliseconds: chartEnd - days * 86_400_000, value: start),
                SubtensorFlowPricePoint(milliseconds: chartEnd, value: end)
            ])
        }
    }
}

final class SubtensorFlowPositionsFeed {
    typealias State = Multistaking.SubtensorStakingState?

    private let lock = NSLock()
    private let observable = Observable<State>(state: nil)
    private var refreshedStates: [Multistaking.SubtensorStakingState] = []

    init(service: MockSubtensorPositionsSyncServiceProtocol) {
        stub(service) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.throttle()).thenDoNothing()

            when(stub.refresh()).then {
                self.publishNextRefresh()
            }

            when(
                stub.add(observer: any(), sendStateOnSubscription: any(), queue: any(), closure: any())
            ).then { observer, sendStateOnSubscription, queue, closure in
                self.add(observer, sendStateOnSubscription: sendStateOnSubscription, queue: queue, closure: closure)
            }

            when(stub.remove(observer: any())).then { observer in
                self.remove(observer)
            }
        }
    }

    func publish(_ state: Multistaking.SubtensorStakingState) {
        lock.lock()
        observable.state = state
        lock.unlock()
    }

    func publishOnRefresh(_ state: Multistaking.SubtensorStakingState) {
        lock.lock()
        refreshedStates.append(state)
        lock.unlock()
    }
}

private extension SubtensorFlowPositionsFeed {
    func publishNextRefresh() {
        lock.lock()

        if !refreshedStates.isEmpty {
            observable.state = refreshedStates.removeFirst()
        }

        lock.unlock()
    }

    func add(
        _ observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<State>.StateChangeClosure
    ) {
        lock.lock()

        observable.addObserver(
            with: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue ?? .global(),
            closure: closure
        )

        lock.unlock()
    }

    func remove(_ observer: AnyObject) {
        lock.lock()
        observable.removeObserver(by: observer)
        lock.unlock()
    }
}

extension SubtensorFlowWorld {
    func stubClaimPreviews(_ previews: [SubtensorStakingPallet.BasketClaimPreview]) {
        stub(apiOperationFactory) { stub in
            when(stub.createBestBlockHashWrapper()).then {
                CompoundOperationWrapper.createWithResult(BittensorApiFixtureWorld.blockHash)
            }

            when(stub.createRootClaimPreviewsWrapper(coldkey: any(), blockHash: any())).then { _, _ in
                CompoundOperationWrapper.createWithResult(previews)
            }
        }
    }

    func stubRootHolds(_ holds: [AccountId: SubtensorRootHold]) {
        stub(rootHoldFactory) { stub in
            when(stub.createHoldsWrapper(coldkey: any(), hotkeys: any())).then { _, hotkeys in
                CompoundOperationWrapper.createWithResult(holds.filter { hotkeys.contains($0.key) })
            }
        }
    }
}

extension SubtensorFlowTestCase {
    func stubPreflight(
        hotkeyOf member: BittensorApiFixtureWorld.Member,
        netuid: UInt16
    ) throws -> MockSubtensorPreflightFactoryProtocol {
        let preflight = try SubtensorFlowActiveStake.preflight(hotkeyOf: member, netuid: netuid)
        let factory = MockSubtensorPreflightFactoryProtocol()

        stub(factory) { stub in
            when(stub.createPreflightWrapper(for: any(), hotkey: any(), netuid: any())).then { _, _, _ in
                CompoundOperationWrapper.createWithResult(preflight)
            }
        }

        return factory
    }

    func awaitPositions(in world: SubtensorFlowWorld) throws -> Multistaking.SubtensorStakingState {
        let service = try XCTUnwrap(world.sharedState.positionsSyncService)
        let delivered = expectation(description: "Positions delivered")
        let observer = NSObject()
        var received: Multistaking.SubtensorStakingState?

        service.add(
            observer: observer,
            sendStateOnSubscription: true,
            queue: DispatchQueue(label: "flow.positions")
        ) { _, state in
            guard received == nil, let state else {
                return
            }

            received = state
            delivered.fulfill()
        }

        wait(for: [delivered], timeout: 10)
        service.remove(observer: observer)

        return try XCTUnwrap(received)
    }

    func awaitClaimable(in world: SubtensorFlowWorld) throws -> SubtensorRootClaimable {
        let service = try XCTUnwrap(world.sharedState.rootClaimableService)
        let delivered = expectation(description: "Claimable delivered")
        let observer = NSObject()
        var received: SubtensorRootClaimable?

        service.add(
            observer: observer,
            sendStateOnSubscription: true,
            queue: DispatchQueue(label: "flow.claimable")
        ) { _, claimable in
            guard received == nil, let claimable else {
                return
            }

            received = claimable
            delivered.fulfill()
        }

        wait(for: [delivered], timeout: 10)
        service.remove(observer: observer)

        return try XCTUnwrap(received)
    }
}
