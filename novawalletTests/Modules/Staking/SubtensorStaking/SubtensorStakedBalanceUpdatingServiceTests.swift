import XCTest
@testable import novawallet
import BigInt
import Cuckoo
import Operation_iOS

final class SubtensorStakedBalanceUpdatingServiceTests: XCTestCase {
    let accountId = Data(repeating: 1, count: 32)
    let otherAccountId = Data(repeating: 9, count: 32)

    func testOnlyTheOwnAccountAndChainAssetChangeResyncs() throws {
        let context = try makeContext()
        let otherChainAssetId = ChainAssetId(chainId: context.chainAsset.chain.chainId, assetId: 1)

        context.service.setup()

        context.eventCenter.notify(
            with: SubtensorStakingChanged(chainAssetId: context.chainAsset.chainAssetId, accountId: otherAccountId)
        )

        context.eventCenter.notify(with: SubtensorStakingChanged(chainAssetId: otherChainAssetId, accountId: accountId))

        drainEvents(of: context)

        verify(context.fetchFactory, never()).createStateWrapper(for: any())

        context.eventCenter.notify(
            with: SubtensorStakingChanged(chainAssetId: context.chainAsset.chainAssetId, accountId: accountId)
        )

        drainEvents(of: context)

        context.service.throttle()

        verify(context.fetchFactory, times(1)).createStateWrapper(for: equal(to: accountId))
    }

    private struct Context {
        let service: SubtensorStakedBalanceUpdatingService
        let fetchFactory: MockSubtensorStakeStateFetchFactoryProtocol
        let eventCenter: EventCenter
        let eventQueue: DispatchQueue
        let chainAsset: ChainAsset
    }

    private func makeContext() throws -> Context {
        let storageFacade = SubstrateStorageTestFacade()
        let repository = AnyDataProviderRepository(
            storageFacade.createRepository(mapper: AnyCoreDataMapper(SubtensorStakedBalanceMapper()))
        )

        let fetchFactory = MockSubtensorStakeStateFetchFactoryProtocol()
        let eventQueue = DispatchQueue(label: "test.subtensor.balance.events")
        let eventCenter = EventCenter(syncQueue: eventQueue)
        let chainAsset = Self.subtensorChainAsset()

        stub(fetchFactory) { stub in
            when(stub.createStateWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(Self.stakingState(stake: 2_000_000_000))
            }
        }

        let service = SubtensorStakedBalanceUpdatingService(
            accountId: accountId,
            chainAsset: chainAsset,
            repository: repository,
            stakeStateFetchFactory: fetchFactory,
            connection: TestJSONRPCEngine(),
            runtimeService: RuntimeCodingServiceStub(
                factory: try RuntimeCodingServiceStub.createBittensorCodingFactory()
            ),
            operationQueue: OperationQueue(),
            workingQueue: DispatchQueue(label: "test.subtensor.balance"),
            logger: Logger.shared,
            eventCenter: eventCenter
        )

        return Context(
            service: service,
            fetchFactory: fetchFactory,
            eventCenter: eventCenter,
            eventQueue: eventQueue,
            chainAsset: chainAsset
        )
    }

    private func drainEvents(of context: Context) {
        context.eventQueue.sync {}
        context.service.workingQueue.sync {}
    }

    private static func stakingState(stake: BigUInt) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 2, count: 32),
                    netuid: SubtensorStakingPallet.rootNetuid,
                    stakeAlpha: stake,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [:]
        )
    }

    private static func subtensorChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }
}
