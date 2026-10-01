import BigInt
import Keystore_iOS
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorStakingSimSwapTests: XCTestCase {
    private var context: Context!

    override func setUpWithError() throws {
        context = try Self.sharedContext.get()
    }

    func testSimSwapTaoForAlphaOutputStaysWithinSpotPriceBand() {
        do {
            let netuid = try context.discoverLiquidNetuid()
            let buy = try context.fetchBuySim()
            let spot = try context.fetchSpotPrice()

            Logger.shared.info("Buy sim on netuid \(netuid): \(buy)")

            XCTAssertGreaterThan(buy.alphaAmount, 0)

            let alphaAtSpot = Context.oneTao * SubtensorStakingPallet.alphaPriceScale / spot

            XCTAssertGreaterThanOrEqual(buy.alphaAmount, alphaAtSpot * 95 / 100)
            XCTAssertLessThanOrEqual(buy.alphaAmount, alphaAtSpot * 105 / 100)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSimSwapAmountsAndFeesReconstructGrossInputsExactly() {
        do {
            let buy = try context.fetchBuySim()
            let sell = try context.fetchSellSim()

            XCTAssertEqual(buy.taoAmount + buy.taoFee, Context.oneTao)
            XCTAssertEqual(sell.alphaAmount + sell.alphaFee, buy.alphaAmount)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRoundTripSimLossApproximatesTwicePoolFee() {
        do {
            let buy = try context.fetchBuySim()
            let sell = try context.fetchSellSim()
            let feeRate = try context.fetchFeeRate()

            XCTAssertGreaterThan(buy.alphaAmount, 0)
            XCTAssertGreaterThan(sell.taoAmount, 0)
            XCTAssertLessThan(sell.taoAmount, Context.oneTao)

            let lossPpm = (Context.oneTao - sell.taoAmount) * 1_000_000 / Context.oneTao
            let feePpm = BigUInt(feeRate) * 1_000_000 / BigUInt(SubtensorStakingPallet.perU16Denominator)

            Logger.shared.info("Round trip loss: \(lossPpm) ppm, pool fee: \(feePpm) ppm")

            XCTAssertGreaterThanOrEqual(lossPpm, 2 * feePpm * 9 / 10)
            XCTAssertLessThanOrEqual(lossPpm, 2 * feePpm + 20000)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAddStakeLimitFeeEstimationReturnsPositiveFee() {
        do {
            let staker = try context.discoverStaker()
            let netuid = try context.discoverLiquidNetuid()
            let spot = try context.fetchSpotPrice()
            let minStake = try context.fetchMinStake()

            let buyLimit = try SubtensorLimitPriceCalculator.buyLimit(
                spot: spot,
                tolerance: Context.limitTolerance
            )

            let call = SubtensorStakingPallet.AddStakeLimitCall(
                hotkey: staker.hotkey,
                netuid: netuid,
                amountStaked: minStake,
                limitPrice: buyLimit,
                allowPartial: false
            )

            let fee = try context.estimateFee { builder in
                try builder.adding(call: call.runtimeCall())
            }

            Logger.shared.info("add_stake_limit fee: \(fee.amount)")

            XCTAssertGreaterThan(fee.amount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRemoveStakeFullLimitWithLimitFeeEstimationReturnsPositiveFee() {
        do {
            let staker = try context.discoverStaker()
            let netuid = try context.discoverLiquidNetuid()
            let spot = try context.fetchSpotPrice()

            let sellLimit = try SubtensorLimitPriceCalculator.sellLimit(
                spot: spot,
                tolerance: Context.limitTolerance
            )

            let call = SubtensorStakingPallet.RemoveStakeFullLimitCall(
                hotkey: staker.hotkey,
                netuid: netuid,
                limitPrice: sellLimit
            )

            let fee = try context.estimateFee { builder in
                try builder.adding(call: call.runtimeCall())
            }

            Logger.shared.info("remove_stake_full_limit with limit fee: \(fee.amount)")

            XCTAssertGreaterThan(fee.amount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLimitPricesFromLiveSpotAreProtectiveAndWithinU64() {
        do {
            let spot = try context.fetchSpotPrice()

            let buyLimit = try SubtensorLimitPriceCalculator.buyLimit(
                spot: spot,
                tolerance: Context.limitTolerance
            )

            let sellLimit = try SubtensorLimitPriceCalculator.sellLimit(
                spot: spot,
                tolerance: Context.limitTolerance
            )

            Logger.shared.info("Spot: \(spot), buy limit: \(buyLimit), sell limit: \(sellLimit)")

            XCTAssertGreaterThan(buyLimit, spot)
            XCTAssertGreaterThan(sellLimit, 0)
            XCTAssertLessThan(sellLimit, spot)
            XCTAssertLessThanOrEqual(buyLimit, BigUInt(UInt64.max))
            XCTAssertLessThanOrEqual(sellLimit, BigUInt(UInt64.max))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension SubtensorStakingSimSwapTests {
    static let chainId = KnowChainId.bittensor

    static let sharedContext = Result { try Context.setup(for: chainId) }

    enum ContextError: Error {
        case chainUnavailable
        case signerUnavailable
        case stakerUnavailable
        case minStakeUnavailable
        case subnetUnavailable
        case spotPriceUnavailable
    }

    struct DiscoveredStaker {
        let hotkey: AccountId
        let coldkey: AccountId
    }

    final class Context {
        static let oneTao = Balance(1_000_000_000)
        static let limitTolerance = BigRational(numerator: 5, denominator: 1000)
        static let liquidCandidateCount = 10
        static let minRequestInterval: TimeInterval = 1

        let storageFacade: StorageFacadeProtocol
        let chainRegistry: ChainRegistryProtocol
        let chain: ChainModel
        let connection: JSONRPCEngine
        let runtimeProvider: RuntimeProviderProtocol
        let selectedAccount: ChainAccountResponse
        let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
        let apiFactory: SubtensorApiOperationFactoryProtocol
        let operationQueue: OperationQueue

        private var lastRunFinishDate: Date?
        private var pinnedBlockHash: BlockHash?
        private var dynamicInfoList: [SubtensorStakingPallet.DynamicInfo]?
        private var liquidNetuid: UInt16?
        private var spotPrice: Balance?
        private var buySim: SubtensorStakingPallet.SimSwapResult?
        private var sellSim: SubtensorStakingPallet.SimSwapResult?
        private var feeRate: UInt16?
        private var delegates: [SubtensorStakingPallet.DelegateInfo]?
        private var staker: DiscoveredStaker?
        private var codingFactory: RuntimeCoderFactoryProtocol?

        init(
            storageFacade: StorageFacadeProtocol,
            chainRegistry: ChainRegistryProtocol,
            chain: ChainModel,
            connection: JSONRPCEngine,
            runtimeProvider: RuntimeProviderProtocol,
            selectedAccount: ChainAccountResponse,
            extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
            apiFactory: SubtensorApiOperationFactoryProtocol,
            operationQueue: OperationQueue
        ) {
            self.storageFacade = storageFacade
            self.chainRegistry = chainRegistry
            self.chain = chain
            self.connection = connection
            self.runtimeProvider = runtimeProvider
            self.selectedAccount = selectedAccount
            self.extrinsicOperationFactory = extrinsicOperationFactory
            self.apiFactory = apiFactory
            self.operationQueue = operationQueue
        }

        static func setup(for chainId: ChainModel.Id) throws -> Context {
            let storageFacade = SubstrateStorageTestFacade()
            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
            let operationQueue = OperationQueue()

            let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: chainId)

            let chain = try withExtendedLifetime(chainRegistry) {
                operationQueue.addOperations(chainWrapper.allOperations, waitUntilFinished: true)

                return try chainWrapper.targetOperation.extractNoCancellableResultData()
            }

            guard
                let chain,
                let connection = chainRegistry.getConnection(for: chainId),
                let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId)
            else {
                throw ContextError.chainUnavailable
            }

            let keychain = InMemoryKeychain()
            let userStorageFacade = UserDataStorageTestFacade()

            let walletSettings = SelectedWalletSettings(
                storageFacade: userStorageFacade,
                operationQueue: operationQueue
            )

            try AccountCreationHelper.createMetaAccountFromMnemonic(
                cryptoType: .sr25519,
                keychain: keychain,
                settings: walletSettings
            )

            guard
                let wallet = walletSettings.value,
                let selectedAccount = wallet.fetch(for: chain.accountRequest())
            else {
                throw ContextError.signerUnavailable
            }

            let extrinsicOperationFactory = ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: storageFacade
            ).createOperationFactory(account: selectedAccount, chain: chain)

            let connectionStore = ChainRegistryRuntimeConnectionStore(
                chainId: chainId,
                chainRegistry: chainRegistry
            )

            let apiFactory = SubtensorApiOperationFactory(
                runtimeConnectionStore: connectionStore,
                operationQueue: operationQueue
            )

            return Context(
                storageFacade: storageFacade,
                chainRegistry: chainRegistry,
                chain: chain,
                connection: connection,
                runtimeProvider: runtimeProvider,
                selectedAccount: selectedAccount,
                extrinsicOperationFactory: extrinsicOperationFactory,
                apiFactory: apiFactory,
                operationQueue: operationQueue
            )
        }

        func run<ResultType>(_ wrapper: CompoundOperationWrapper<ResultType>) throws -> ResultType {
            try withExtendedLifetime(self) {
                paceRemoteRequests()

                operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

                lastRunFinishDate = Date()

                return try wrapper.targetOperation.extractNoCancellableResultData()
            }
        }

        func estimateFee(with closure: @escaping ExtrinsicBuilderClosure) throws -> ExtrinsicFeeProtocol {
            try run(extrinsicOperationFactory.estimateFeeOperation(closure, payingIn: nil))
        }

        func fetchPinnedBlockHash() throws -> BlockHash {
            if let pinnedBlockHash {
                return pinnedBlockHash
            }

            let fetched = try run(apiFactory.createBestBlockHashWrapper())
            pinnedBlockHash = fetched

            return fetched
        }

        func discoverLiquidNetuid() throws -> UInt16 {
            if let liquidNetuid {
                return liquidNetuid
            }

            let blockHash = try fetchPinnedBlockHash()

            let candidates = try fetchDynamicInfoList()
                .filter { $0.netuid != SubtensorStakingPallet.rootNetuid }
                .sorted { $0.taoIn > $1.taoIn }
                .prefix(Self.liquidCandidateCount)
                .map(\.netuid)

            let enabled = try run(
                apiFactory.createSubtokenEnabledWrapper(for: candidates, blockHash: blockHash)
            )

            guard let netuid = candidates.first(where: { enabled.contains($0) }) else {
                throw ContextError.subnetUnavailable
            }

            liquidNetuid = netuid

            return netuid
        }

        func fetchSpotPrice() throws -> Balance {
            if let spotPrice {
                return spotPrice
            }

            let netuid = try discoverLiquidNetuid()
            let blockHash = try fetchPinnedBlockHash()

            let prices = try run(apiFactory.createAlphaPricesWrapper(at: blockHash))

            guard
                let price = prices.first(where: { $0.netuid == netuid })?.price,
                price > 0
            else {
                throw ContextError.spotPriceUnavailable
            }

            spotPrice = price

            return price
        }

        func fetchBuySim() throws -> SubtensorStakingPallet.SimSwapResult {
            if let buySim {
                return buySim
            }

            let netuid = try discoverLiquidNetuid()
            let blockHash = try fetchPinnedBlockHash()

            let fetched = try run(
                apiFactory.createSimSwapTaoForAlphaWrapper(
                    netuid: netuid,
                    taoAmount: Self.oneTao,
                    blockHash: blockHash
                )
            )

            buySim = fetched

            return fetched
        }

        func fetchSellSim() throws -> SubtensorStakingPallet.SimSwapResult {
            if let sellSim {
                return sellSim
            }

            let buy = try fetchBuySim()
            let netuid = try discoverLiquidNetuid()
            let blockHash = try fetchPinnedBlockHash()

            let fetched = try run(
                apiFactory.createSimSwapAlphaForTaoWrapper(
                    netuid: netuid,
                    alphaAmount: buy.alphaAmount,
                    blockHash: blockHash
                )
            )

            sellSim = fetched

            return fetched
        }

        func fetchFeeRate() throws -> UInt16 {
            if let feeRate {
                return feeRate
            }

            let netuid = try discoverLiquidNetuid()
            let blockHash = try fetchPinnedBlockHash()

            let fetched = try run(apiFactory.createFeeRateWrapper(for: netuid, blockHash: blockHash))
            feeRate = fetched

            return fetched
        }

        func discoverStaker() throws -> DiscoveredStaker {
            if let staker {
                return staker
            }

            let candidates = try fetchDelegates().flatMap { delegate in
                delegate.nominators.map { (hotkey: delegate.delegateSs58, nomination: $0) }
            }

            let best = candidates.max { $0.nomination.rootStake < $1.nomination.rootStake }

            guard let best, best.nomination.rootStake > 0 else {
                throw ContextError.stakerUnavailable
            }

            let discovered = DiscoveredStaker(hotkey: best.hotkey, coldkey: best.nomination.nominator)
            staker = discovered

            return discovered
        }

        func fetchMinStake() throws -> Balance {
            let codingFactory = try fetchCoderFactory()

            guard let constant = codingFactory.getConstant(for: SubtensorStakingPallet.initialMinStakePath) else {
                throw ContextError.minStakeUnavailable
            }

            let decoder = try codingFactory.createDecoder(from: constant.value)
            let minStake: StringScaleMapper<UInt64> = try decoder.read(of: constant.type)

            return Balance(minStake.value)
        }

        private func fetchCoderFactory() throws -> RuntimeCoderFactoryProtocol {
            if let codingFactory {
                return codingFactory
            }

            let fetched = try withExtendedLifetime(self) {
                let operation = runtimeProvider.fetchCoderFactoryOperation()

                operationQueue.addOperations([operation], waitUntilFinished: true)

                return try operation.extractNoCancellableResultData()
            }

            codingFactory = fetched

            return fetched
        }

        private func fetchDynamicInfoList() throws -> [SubtensorStakingPallet.DynamicInfo] {
            if let dynamicInfoList {
                return dynamicInfoList
            }

            let blockHash = try fetchPinnedBlockHash()

            let fetched = try run(apiFactory.createAllDynamicInfoWrapper(at: blockHash)).compactMap { $0 }
            dynamicInfoList = fetched

            return fetched
        }

        private func fetchDelegates() throws -> [SubtensorStakingPallet.DelegateInfo] {
            if let delegates {
                return delegates
            }

            let fetched = try run(apiFactory.createDelegatesWrapper(at: nil))
            delegates = fetched

            return fetched
        }

        private func paceRemoteRequests() {
            guard let lastRunFinishDate else {
                return
            }

            let remaining = Self.minRequestInterval - Date().timeIntervalSince(lastRunFinishDate)

            if remaining > 0 {
                Thread.sleep(forTimeInterval: remaining)
            }
        }
    }
}

private extension SubtensorStakingPallet.DelegateNomination {
    var rootStake: Balance {
        stakes.first { $0.netuid == SubtensorStakingPallet.rootNetuid }?.stake ?? 0
    }
}
