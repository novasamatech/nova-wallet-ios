import BigInt
import Keystore_iOS
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorStakingWritePathTests: XCTestCase {
    private var context: Context!

    override func setUpWithError() throws {
        context = try Self.sharedContext.get()
    }

    func testAddStakeSignedExtrinsicRoundTripsAgainstLiveMetadata() {
        do {
            let staker = try context.discoverStaker()
            let minStake = try context.fetchMinStake()

            let callModel = SubtensorStakingCallModel.stake(
                SubtensorStakeModel(
                    hotkey: staker.hotkey,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    amount: minStake
                )
            )

            let extrinsicData = try context.buildSignedExtrinsic(with: callModel.extrinsicBuilderClosure)

            Logger.shared.info("Built extrinsic: \(extrinsicData.toHex(includePrefix: true))")

            let codingFactory = try context.fetchCoderFactory()
            let jsonContext = codingFactory.createRuntimeJsonContext()

            let decoder = try codingFactory.createDecoder(from: extrinsicData)
            let extrinsicJson = try decoder.read(type: GenericType.extrinsic.name)
            let extrinsic = try extrinsicJson.map(to: Extrinsic.self, with: jsonContext.toRawContext())

            let signed = try XCTUnwrap(extrinsic.getSignedExtrinsic())

            XCTAssertEqual(
                ExtrinsicExtraction.getSender(from: extrinsic, codingFactory: codingFactory),
                context.selectedAccount.accountId
            )

            let signature = try signed.signature.signature.map(
                to: MultiSignature.self,
                with: jsonContext.toRawContext()
            )

            guard case let .sr25519(rawSignature) = signature else {
                XCTFail("Unexpected signature type")
                return
            }

            XCTAssertEqual(rawSignature.count, 64)

            XCTAssertEqual(Set(signed.signature.extra.keys), Set(codingFactory.metadata.getSignedExtensions()))

            XCTAssertEqual(signed.signature.extra.getTip(), 0)
            XCTAssertEqual(signed.signature.extra.getNonce(), 0)

            guard case let .mortal(period, phase) = try XCTUnwrap(signed.signature.extra.getEra()) else {
                XCTFail("Expected mortal era")
                return
            }

            XCTAssertLessThan(phase, period)

            let call: RuntimeCall<SubtensorStakingPallet.AddStakeCall> = try ExtrinsicExtraction.getTypedCall(
                from: signed.call,
                context: jsonContext
            )

            XCTAssertEqual(call.moduleName, SubtensorStakingPallet.name)
            XCTAssertEqual(call.callName, "add_stake")
            XCTAssertEqual(call.args.hotkey, staker.hotkey)
            XCTAssertEqual(call.args.netuid, SubtensorStakingPallet.rootNetuid)
            XCTAssertEqual(call.args.amountStaked, minStake)

            let encoder = codingFactory.createEncoder()
            try encoder.append(json: extrinsicJson, type: GenericType.extrinsic.name)

            XCTAssertEqual(try encoder.encode(), extrinsicData)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChainIdentityMatchesLiveGenesis() {
        do {
            let genesisHash = try context.fetchGenesisHash()

            XCTAssertEqual(genesisHash.withoutHexPrefix(), context.chain.chainId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAddStakeFeeEstimationReturnsPositiveFee() {
        do {
            let staker = try context.discoverStaker()
            let minStake = try context.fetchMinStake()

            let callModel = SubtensorStakingCallModel.stake(
                SubtensorStakeModel(
                    hotkey: staker.hotkey,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    amount: minStake
                )
            )

            let fee = try context.estimateFee(with: callModel.extrinsicBuilderClosure)

            Logger.shared.info("add_stake fee: \(fee.amount)")

            XCTAssertGreaterThan(fee.amount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRemoveStakeFullLimitFeeEstimationReturnsPositiveFee() {
        do {
            let staker = try context.discoverStaker()

            let callModel = SubtensorStakingCallModel.unstake(
                SubtensorUnstakeModel(
                    hotkey: staker.hotkey,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    amount: 0,
                    exitHotkeys: [staker.hotkey]
                )
            )

            let fee = try context.estimateFee(with: callModel.extrinsicBuilderClosure)

            Logger.shared.info("remove_stake_full_limit fee: \(fee.amount)")

            XCTAssertGreaterThan(fee.amount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClaimRootWithHotkeyFeeEstimationReturnsPositiveFee() {
        do {
            let staker = try context.discoverStaker()

            let callModel = SubtensorStakingCallModel.claim(hotkey: staker.hotkey)

            let fee = try context.estimateFee(with: callModel.extrinsicBuilderClosure)

            Logger.shared.info("claim_root_with_hotkey fee: \(fee.amount)")

            XCTAssertGreaterThan(fee.amount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRootBasketOwedMatchesPositionsSumForDiscoveredStaker() {
        do {
            let staker = try context.discoverStaker()
            let blockHash = try context.run(context.apiFactory.createBestBlockHashWrapper())

            let owed = try context.run(
                context.apiFactory.createRootBasketOwedWrapper(for: staker.coldkey, blockHash: blockHash)
            )

            let positions = try context.run(
                context.apiFactory.createRootBasketPositionsWrapper(for: staker.coldkey, blockHash: blockHash)
            )

            Logger.shared.info("Basket owed: \(owed), positions: \(positions.count)")

            for position in positions {
                XCTAssertGreaterThan(position.owedShares, 0, "hotkey \(position.hotkey.toHex())")
            }

            XCTAssertEqual(owed, positions.reduce(Balance(0)) { $0 + $1.payout })
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension SubtensorStakingWritePathTests {
    static let chainId = KnowChainId.bittensor

    static let sharedContext = Result { try Context.setup(for: chainId) }

    enum ContextError: Error {
        case chainUnavailable
        case signerUnavailable
        case stakerUnavailable
        case minStakeUnavailable
    }

    struct DiscoveredStaker {
        let hotkey: AccountId
        let coldkey: AccountId
    }

    final class Context {
        let storageFacade: StorageFacadeProtocol
        let chainRegistry: ChainRegistryProtocol
        let chain: ChainModel
        let connection: JSONRPCEngine
        let runtimeProvider: RuntimeProviderProtocol
        let selectedAccount: ChainAccountResponse
        let signer: SigningWrapperProtocol
        let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
        let apiFactory: SubtensorApiOperationFactoryProtocol
        let operationQueue: OperationQueue

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
            signer: SigningWrapperProtocol,
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
            self.signer = signer
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

            let signer = SigningWrapper(
                keystore: keychain,
                metaId: wallet.metaId,
                accountResponse: selectedAccount,
                settingsManager: InMemorySettingsManager()
            )

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
                signer: signer,
                extrinsicOperationFactory: extrinsicOperationFactory,
                apiFactory: apiFactory,
                operationQueue: operationQueue
            )
        }

        func run<ResultType>(_ wrapper: CompoundOperationWrapper<ResultType>) throws -> ResultType {
            try withExtendedLifetime(self) {
                operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

                return try wrapper.targetOperation.extractNoCancellableResultData()
            }
        }

        func buildSignedExtrinsic(with closure: @escaping ExtrinsicBuilderClosure) throws -> Data {
            let wrapper = extrinsicOperationFactory.buildExtrinsic(
                closure,
                signer: signer,
                payingFeeIn: nil
            )

            let model = try run(wrapper)

            return try Data(hexString: model.extrinsic)
        }

        func estimateFee(with closure: @escaping ExtrinsicBuilderClosure) throws -> ExtrinsicFeeProtocol {
            try run(extrinsicOperationFactory.estimateFeeOperation(closure, payingIn: nil))
        }

        func fetchCoderFactory() throws -> RuntimeCoderFactoryProtocol {
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

        func fetchMinStake() throws -> Balance {
            let codingFactory = try fetchCoderFactory()

            guard let constant = codingFactory.getConstant(for: SubtensorStakingPallet.initialMinStakePath) else {
                throw ContextError.minStakeUnavailable
            }

            let decoder = try codingFactory.createDecoder(from: constant.value)
            let minStake: StringScaleMapper<UInt64> = try decoder.read(of: constant.type)

            return Balance(minStake.value)
        }

        func fetchGenesisHash() throws -> String {
            try withExtendedLifetime(self) {
                let operation = BlockHashOperationFactory().createBlockHashOperation(
                    connection: connection,
                    for: { 0 }
                )

                operationQueue.addOperations([operation], waitUntilFinished: true)

                return try operation.extractNoCancellableResultData()
            }
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

        private func fetchDelegates() throws -> [SubtensorStakingPallet.DelegateInfo] {
            if let delegates {
                return delegates
            }

            let fetched = try run(apiFactory.createDelegatesWrapper())
            delegates = fetched

            return fetched
        }
    }
}

private extension SubtensorStakingPallet.DelegateNomination {
    var rootStake: Balance {
        stakes.first { $0.netuid == SubtensorStakingPallet.rootNetuid }?.stake ?? 0
    }
}
