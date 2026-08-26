import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorRewardEngineTests: XCTestCase {
    private var context: Context!

    override func setUpWithError() throws {
        context = try Self.sharedContext.get()
    }

    func testTaoWeightIsAProperFractionOfItsDenominator() {
        do {
            let inputs = try context.fetchInputs()

            Logger.shared.info("TaoWeight: \(inputs.taoWeight)")

            XCTAssertGreaterThan(inputs.taoWeight, 0)
            XCTAssertLessThan(inputs.taoWeight, SubtensorRootAprCalculator.taoWeightScale)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSubnetOwnerCutStaysBelowItsDenominator() {
        do {
            let ownerCut = try context.fetchOwnerCut()

            Logger.shared.info("Owner cut: \(ownerCut)")

            XCTAssertGreaterThan(ownerCut, 0)
            XCTAssertLessThan(ownerCut, SubtensorStakingPallet.perU16Denominator)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// spec §6.2 release gate: the engine's operands are checked against the TAO the network
    /// actually pushes into the beta baskets, sampled across a window of blocks
    /// (subtensor: `pallets/subtensor/src/staking/basket_views.rs:112-113`)
    func testModelledRootInflowMatchesObservedBasketAccrual() throws {
        let params = try context.fetchParams()

        let head = try context.fetchHeadBlockNumber()
        let headNav = try context.fetchBasketNav(at: head)

        // the public endpoint prunes state, so the widest still-retained window wins: a longer
        // span averages over more staggered per-subnet tempo deposits
        var sampled: (window: BlockNumber, nav: Balance)?

        for window in Self.gateWindowCandidates where sampled == nil {
            sampled = (try? context.fetchBasketNav(at: head - window)).map { (window, $0) }
        }

        guard let sampled else {
            throw XCTSkip("No retained block carries the basket nav")
        }

        guard headNav > sampled.nav else {
            throw XCTSkip("Basket nav did not grow across the \(sampled.window) block window")
        }

        let observedPerBlock = (headNav - sampled.nav) / BigUInt(sampled.window)

        let modelledPerBlock = SubtensorRootAprCalculator.perBlockRootRaoScaled(for: params) /
            SubtensorRootAprCalculator.proportionScale

        Logger.shared.info(
            "Root inflow rao per block over \(sampled.window) blocks — " +
                "modelled \(modelledPerBlock), observed \(observedPerBlock)"
        )

        XCTAssertGreaterThan(modelledPerBlock, 0)
        XCTAssertGreaterThan(observedPerBlock * Self.gateToleranceFactor, modelledPerBlock)
        XCTAssertGreaterThan(modelledPerBlock * Self.gateToleranceFactor, observedPerBlock)
    }

    func testRootProportionIsStrictlyBetweenZeroAndOneForEveryEmittingSubnet() {
        do {
            let params = try context.fetchParams()

            let emitting = params.subnets.filter {
                $0.alphaOutEmission > 0 && $0.netuid != SubtensorStakingPallet.rootNetuid
            }

            XCTAssertFalse(emitting.isEmpty)

            for subnet in emitting {
                let proportion = SubtensorRootAprCalculator.rootProportion(
                    taoWeight: params.taoWeight,
                    rootTao: params.rootTao,
                    alphaIssuance: subnet.alphaIssuance
                )

                XCTAssertGreaterThan(proportion, 0, "netuid \(subnet.netuid)")
                XCTAssertLessThan(
                    proportion,
                    SubtensorRootAprCalculator.proportionScale,
                    "netuid \(subnet.netuid)"
                )
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRootReservesAndRootStakeAreBothPositiveAndOfTheSameOrder() {
        do {
            let params = try context.fetchParams()

            Logger.shared.info("Root tao: \(params.rootTao), root stake: \(params.rootStake)")

            XCTAssertGreaterThan(params.rootTao, 0)
            XCTAssertGreaterThan(params.rootStake, 0)
            XCTAssertLessThan(params.rootTao, params.rootStake * 2)
            XCTAssertGreaterThan(params.rootTao * 2, params.rootStake)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEngineAprIsFiniteAndInsideABroadBand() {
        do {
            let engine = SubtensorRewardCalculatorEngine(params: try context.fetchParams())

            guard let ppm = SubtensorRootAprCalculator.aprPpm(for: engine.params) else {
                return XCTFail("Expected an apr for live operands")
            }

            Logger.shared.info("Gross root apr ppm: \(ppm)")

            XCTAssertGreaterThan(ppm, 0)
            XCTAssertLessThan(ppm, BigUInt(500_000))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEngineAprDecreasesAsTheDelegateTakeGrows() {
        do {
            let params = try context.fetchParams()

            let gross = try XCTUnwrap(SubtensorRootAprCalculator.aprPpm(for: params, take: 0))
            let netted = try XCTUnwrap(SubtensorRootAprCalculator.aprPpm(for: params, take: 11796))

            XCTAssertLessThan(netted, gross)
            XCTAssertEqual(SubtensorRootAprCalculator.aprPpm(for: params, take: 65535), BigUInt(0))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSummedMovingPriceKeepsRootEmissionActive() {
        do {
            let params = try context.fetchParams()

            let summed = params.subnets
                .filter { $0.alphaOutEmission > 0 && $0.netuid != SubtensorStakingPallet.rootNetuid }
                .reduce(BigUInt.zero) { $0 + $1.movingPriceBits }

            Logger.shared.info(
                "Summed moving price bits: \(summed) vs cutoff " +
                    "\(SubtensorRootAprCalculator.rootSellPriceThresholdBits)"
            )

            XCTAssertFalse(SubtensorRootAprCalculator.isRootEmissionPaused(subnets: params.subnets))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEngineWithholdsAprWhenSummedMovingPriceFallsToTheCutoff() {
        do {
            let params = try context.fetchParams()

            let recycled = SubtensorRootAprCalculator.Params(
                taoWeight: params.taoWeight,
                rootTao: params.rootTao,
                rootStake: params.rootStake,
                ownerCut: params.ownerCut,
                subnets: params.subnets.map {
                    SubtensorRootAprCalculator.Subnet(
                        netuid: $0.netuid,
                        alphaOutEmission: $0.alphaOutEmission,
                        alphaIssuance: $0.alphaIssuance,
                        price: $0.price,
                        movingPriceBits: 0,
                        ownerCutEnabled: $0.ownerCutEnabled
                    )
                }
            )

            let engine = SubtensorRewardCalculatorEngine(params: recycled)

            XCTAssertTrue(engine.isRootEmissionPaused)
            XCTAssertNil(engine.rootAnnualReturn())
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEveryRootStakeInfoRowCarriesNoAlphaDividends() {
        do {
            let coldkey = try context.discoverRootStakedColdkey()

            let stakeInfoList = try context.run(context.apiFactory.createStakeInfoWrapper(for: coldkey))

            let rootRows = stakeInfoList.filter { $0.netuid == SubtensorStakingPallet.rootNetuid }

            XCTAssertFalse(rootRows.isEmpty)

            for row in rootRows {
                XCTAssertEqual(row.emission, 0, "hotkey \(row.hotkey.toHex())")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension SubtensorRewardEngineTests {
    static let chainId = KnowChainId.bittensor

    /// widest first: per-subnet tempo deposits are staggered, so a longer span averages more of
    /// them, but a pruning endpoint only serves state a few hundred blocks back
    static let gateWindowCandidates: [BlockNumber] = [240, 180, 120, 60]

    /// the gate exists to catch an operand wrong by an order of magnitude, not to pin a rate:
    /// claims drain the basket and deposits arrive per tempo, so the window is inherently noisy
    static let gateToleranceFactor = BigUInt(4)

    static let sharedContext = Result { try Context.setup(for: chainId) }

    enum ContextError: Error {
        case chainUnavailable
        case stakerUnavailable
    }

    final class Context {
        let chainId: ChainModel.Id
        let chainRegistry: ChainRegistryProtocol
        let apiFactory: SubtensorApiOperationFactoryProtocol
        let aprFactory: SubtensorRootAprOperationFactoryProtocol
        let operationQueue: OperationQueue

        private let blockHashFactory = BlockHashOperationFactory()

        private var inputs: SubtensorRootAprInputs?
        private var ownerCut: UInt16?
        private var params: SubtensorRootAprCalculator.Params?

        init(
            chainId: ChainModel.Id,
            chainRegistry: ChainRegistryProtocol,
            apiFactory: SubtensorApiOperationFactoryProtocol,
            aprFactory: SubtensorRootAprOperationFactoryProtocol,
            operationQueue: OperationQueue
        ) {
            self.chainId = chainId
            self.chainRegistry = chainRegistry
            self.apiFactory = apiFactory
            self.aprFactory = aprFactory
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

            guard chain != nil else {
                throw ContextError.chainUnavailable
            }

            let connectionStore = ChainRegistryRuntimeConnectionStore(
                chainId: chainId,
                chainRegistry: chainRegistry
            )

            return Context(
                chainId: chainId,
                chainRegistry: chainRegistry,
                apiFactory: SubtensorApiOperationFactory(
                    runtimeConnectionStore: connectionStore,
                    operationQueue: operationQueue
                ),
                aprFactory: SubtensorRootAprOperationFactory(
                    runtimeConnectionStore: connectionStore,
                    operationQueue: operationQueue
                ),
                operationQueue: operationQueue
            )
        }

        func run<ResultType>(_ wrapper: CompoundOperationWrapper<ResultType>) throws -> ResultType {
            try withExtendedLifetime(self) {
                operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

                return try wrapper.targetOperation.extractNoCancellableResultData()
            }
        }

        func fetchInputs() throws -> SubtensorRootAprInputs {
            if let inputs {
                return inputs
            }

            let fetched = try run(aprFactory.createInputsWrapper())
            inputs = fetched

            return fetched
        }

        func fetchOwnerCut() throws -> UInt16 {
            if let ownerCut {
                return ownerCut
            }

            let fetched = try run(apiFactory.createSubnetOwnerCutWrapper())
                ?? SubtensorStakingPallet.defaultSubnetOwnerCut

            ownerCut = fetched

            return fetched
        }

        func fetchHeadBlockNumber() throws -> BlockNumber {
            let factory = BlockNumberOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )

            return try run(factory.createWrapper(for: chainId))
        }

        func fetchBasketNav(at blockNumber: BlockNumber) throws -> Balance {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let hashOperation = blockHashFactory.createBlockHashOperation(
                connection: connection
            ) { blockNumber }

            let blockHash = try run(CompoundOperationWrapper(targetOperation: hashOperation))

            return try run(apiFactory.createRootBasketTotalNavWrapper(at: blockHash))
        }

        func fetchParams() throws -> SubtensorRootAprCalculator.Params {
            if let params {
                return params
            }

            let dynamicInfos = try run(apiFactory.createAllDynamicInfoWrapper()).compactMap { $0 }
            let subnetPrices = try run(apiFactory.createAlphaPricesWrapper())

            let prices = subnetPrices.reduce(into: [UInt16: Balance]()) { accum, subnetPrice in
                accum[subnetPrice.netuid] = subnetPrice.price
            }

            let fetchedInputs = try fetchInputs()

            let subnetsInfo = SubtensorSubnetsInfo(
                subnets: dynamicInfos,
                prices: prices,
                subtokenEnabled: [],
                ownerCut: try fetchOwnerCut()
            )

            guard
                let built = SubtensorRewardCalculatorService.makeParams(
                    subnetsInfo: subnetsInfo,
                    inputs: fetchedInputs
                ) else {
                throw ContextError.chainUnavailable
            }

            params = built

            return built
        }

        func discoverRootStakedColdkey() throws -> AccountId {
            let rootStake: (SubtensorStakingPallet.DelegateNomination) -> Balance = { nomination in
                nomination.stakes
                    .first { $0.netuid == SubtensorStakingPallet.rootNetuid }?.stake ?? 0
            }

            let staker = try run(apiFactory.createDelegatesWrapper())
                .flatMap(\.nominators)
                .max { rootStake($0) < rootStake($1) }

            guard let staker, rootStake(staker) > 0 else {
                throw ContextError.stakerUnavailable
            }

            return staker.nominator
        }
    }
}
