import Foundation
import Cuckoo
import Keystore_iOS
import NovaAppAttest
import Operation_iOS
import XCTest
@testable import novawallet

final class SubtensorFlowClock {
    private let lock = NSLock()
    private var current: TimeInterval

    init(now: TimeInterval = 10000) {
        current = now
    }

    var now: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        current += interval
        lock.unlock()
    }
}

final class SubtensorFlowWorld {
    let clock: SubtensorFlowClock
    let attestation: SubtensorFlowAttestation
    let chainAsset: ChainAsset
    let subnetsService: MockSubtensorSubnetsServiceProtocol
    let quoteOperationFactory: MockSubtensorQuoteOperationFactoryProtocol
    let rootHoldFactory: MockSubtensorRootHoldFactoryProtocol
    let apiOperationFactory: MockSubtensorApiOperationFactoryProtocol
    let positionsSyncService: MockSubtensorPositionsSyncServiceProtocol
    let settingsManager: InMemorySettingsManager
    let chainRegistry: MockChainRegistryProtocol
    let sharedState: SubtensorStakingSharedStateProtocol

    private let factory: StakingSharedStateFactory
    private let stakingOption: Multistaking.ChainAssetOption
    private let processServices: SubtensorStakingProcessServices
    private var bittensorCodingFactory: RuntimeCoderFactoryProtocol?

    init(novaFeeBeneficiary: AccountId? = SubtensorNovaFeeCalculator.defaultBeneficiary) throws {
        let clock = SubtensorFlowClock()
        let attestation = SubtensorFlowAttestation()
        let chainAsset = SubtensorFlowChainWorld.chainAsset()
        let stakingOption = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor)
        let positionsSyncService = MockSubtensorPositionsSyncServiceProtocol()

        self.clock = clock
        self.attestation = attestation
        self.chainAsset = chainAsset
        self.positionsSyncService = positionsSyncService
        subnetsService = MockSubtensorSubnetsServiceProtocol()
        quoteOperationFactory = MockSubtensorQuoteOperationFactoryProtocol()
        rootHoldFactory = MockSubtensorRootHoldFactoryProtocol()
        apiOperationFactory = MockSubtensorApiOperationFactoryProtocol()
        settingsManager = InMemorySettingsManager()
        chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chainAsset.chain])

        let transport = BittensorAttestedTransport(
            holder: attestation.holder,
            exchangeGate: BackendAttestationExchangeGate(operationQueue: OperationQueue()),
            session: SubtensorFlowURLProtocol.makeSession(),
            operationQueue: OperationQueue(),
            timeProvider: { clock.now },
            logger: Logger.shared
        )

        let cache = BittensorApiResponseCache(
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            timeProvider: { clock.now },
            jitterProvider: { 0 }
        )

        let eventCenter = EventCenter()

        let bittensorApiOperationFactory = BittensorApiOperationFactory(
            transport: transport,
            cache: cache,
            logger: Logger.shared
        )

        let processServices = SubtensorStakingProcessServices(
            bittensorApiOperationFactory: bittensorApiOperationFactory,
            subnetLogosProvider: SubtensorSubnetLogosProvider(url: SubtensorFlowHost.subnetLogos),
            subnetMarketsService: SubtensorSubnetMarketsService(
                coingeckoOperationFactory: CoingeckoOperationFactory(),
                operationQueue: OperationQueue(),
                logger: Logger.shared
            ),
            maxApyResolution: SubtensorMaxApyResolution(),
            costBasisService: SubtensorCostBasisService(
                apiOperationFactory: bittensorApiOperationFactory,
                operationQueue: OperationQueue(),
                eventCenter: eventCenter,
                timeProvider: { clock.now }
            ),
            isFixtureMode: true
        )

        let chainServices = SubtensorStakingChainServices(
            apiOperationFactory: apiOperationFactory,
            subnetsService: subnetsService,
            quoteOperationFactory: quoteOperationFactory,
            rootHoldFactory: rootHoldFactory,
            positionsSyncServiceFactory: { _ in positionsSyncService },
            novaFeeCalculator: SubtensorNovaFeeCalculator(beneficiary: novaFeeBeneficiary),
            settingsManager: settingsManager
        )

        let factory = StakingSharedStateFactory(
            storageFacade: SubstrateStorageTestFacade(),
            chainRegistry: chainRegistry,
            delegatedAccountSyncService: nil,
            eventCenter: eventCenter,
            syncOperationQueue: OperationQueue(),
            repositoryOperationQueue: OperationQueue(),
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        self.factory = factory
        self.stakingOption = stakingOption
        self.processServices = processServices

        sharedState = try factory.createSubtensorStaking(
            for: stakingOption,
            processServices: processServices,
            chainServices: chainServices
        )
    }

    var earnServices: SubtensorEarnServices {
        sharedState.earnServices
    }

    func createProductionWiredNovaFeeCalculator() throws -> SubtensorNovaFeeCalculator {
        let tradeQuoteFactory = try factory.createSubtensorStaking(for: stakingOption, processServices: processServices)
            .earnServices
            .tradeQuoteFactory

        return try XCTUnwrap(tradeQuoteFactory as? SubtensorTradeQuoteFactory).feeCalculator
    }

    func stubSubnets(_ info: SubtensorSubnetsInfo) {
        stub(subnetsService) { stub in
            when(stub.fetchSubnetsInfo(runningCompletionIn: any(), completion: any())).then { queue, completion in
                queue.async {
                    completion(.success(info))
                }
            }
        }
    }

    func stubQuotes(_ quotes: [SubtensorQuote]) {
        stub(quoteOperationFactory) { stub in
            when(stub.createQuoteWrapper(for: any())).then { args in
                guard let quote = quotes.first(where: { $0.args == args }) else {
                    XCTFail("Unexpected chain quote \(args)")
                    return .createWithError(SubtensorQuoteError.quoteUnavailable(netuid: args.netuid))
                }

                return .createWithResult(quote)
            }
        }
    }

    func createStakingOperationService(
        networkFee: Balance,
        submitMonitor: ExtrinsicSubmitMonitorFactoryProtocol = ExtrinsicSubmitMonitorFactoryStub.dummy()
    ) throws -> SubtensorStakingOperationServiceProtocol {
        try sharedState.createStakingOperationService(
            for: SubtensorFlowChainWorld.coldkey,
            extrinsicService: ExtrinsicServiceStub(
                feeResult: .success(
                    ExtrinsicFee(amount: networkFee, payer: nil, weight: .init(refTime: 0, proofSize: 0))
                ),
                submittedModelResult: .failure(BaseOperationError.parentOperationCancelled)
            ),
            extrinsicSubmitMonitor: submitMonitor,
            signer: try DummySigner(cryptoType: .sr25519)
        )
    }

    func createPresetFactory() -> SubtensorValidatorPresetFactoryProtocol {
        SubtensorValidatorPresetFactory(
            directoryService: earnServices.validatorDirectoryService,
            recommendationService: earnServices.recommendationService,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    func useBittensorRuntime() throws -> RuntimeCoderFactoryProtocol {
        if let bittensorCodingFactory {
            return bittensorCodingFactory
        }

        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let runtimeProvider = MockRuntimeProviderProtocol().applyDefault(for: chainAsset.chain.chainId)

        stub(runtimeProvider) { stub in
            when(stub.fetchCoderFactoryOperation()).then {
                BaseOperation.createWithResult(codingFactory)
            }
        }

        stub(chainRegistry) { stub in
            when(stub.getRuntimeProvider(for: any())).thenReturn(runtimeProvider)
        }

        bittensorCodingFactory = codingFactory

        return codingFactory
    }
}
