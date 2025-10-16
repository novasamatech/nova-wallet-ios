import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk
import Operation_iOS

class AutocompounDelegateStakeTests: XCTestCase {
    var extrinsicService: ExtrinsicServiceProtocol?

    func testFetchExtrinsicParams() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d"

        let request = ParaStkYieldBoostRequest(
            amountToStake: 1_000_000_000_000,
            collator: "6AEG2WKRVvZteWWT3aMkk2ZE21FvURqiJkYpXimukub8Zb9C"
        )

        // when

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Can't find connection")
            return
        }

        let wrapper = ParaStkYieldBoostOperationFactory().createAutocompoundParamsOperation(
            for: connection,
            request: request
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let response = try wrapper.targetOperation.extractNoCancellableResultData()

            Logger.shared.info("Response: \(response)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchStakingTasks() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d"
        let accountId = try "6Agvz83pASAvHw4NFUCUhDvs4ZuFd1rMcDjayzUx1Hqg3hU3".toAccountId()

        // when

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Can't find connection")
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            XCTFail("Can't find runtime provider")
            return
        }

        let remoteRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let wrapper = AutomationTimeOperationFactory(requestFactory: remoteRequestFactory).createTasksFetchOperation(
            for: connection,
            runtimeProvider: runtimeProvider,
            account: accountId,
            at: nil
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let response = try wrapper.targetOperation.extractNoCancellableResultData()

            Logger.shared.info("Response: \(response)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchingExecutionFee() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d"

        // when

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Can't find connection")
            return
        }

        let wrapper = ParaStkYieldBoostOperationFactory().createAutocompoundFeeOperation(for: connection)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let fee = try wrapper.targetOperation.extractNoCancellableResultData()

            Logger.shared.info("Execution fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchEveryDayExecutionTime() {
        perforExecutionTimeTest(for: 1)
    }

    func testFetchEvery5DayExecutionTime() {
        perforExecutionTimeTest(for: 5)
    }

    func testScheduleAutocompoundFee() throws {
        let delegatorId = try "6Agvz83pASAvHw4NFUCUhDvs4ZuFd1rMcDjayzUx1Hqg3hU3".toAccountId()
        let collatorId = try "6AEG2WKRVvZteWWT3aMkk2ZE21FvURqiJkYpXimukub8Zb9C".toAccountId()
        let period: UInt = 1
        let accountMinimum = BigUInt(10_000_000_000_000)

        try performScheduleAutocompoundFeeEstimation(
            for: delegatorId,
            collator: collatorId,
            period: period,
            accountMinimum: accountMinimum
        )
    }

    func testCancelTaskFee() throws {
        let taskId = AutomationTime.TaskId.random(of: 32)!

        performCancelTaskFeeEstimation(for: taskId)
    }

    private func performScheduleAutocompoundFeeEstimation(
        for delegator: AccountId,
        collator: AccountId,
        period: UInt,
        accountMinimum: BigUInt
    ) throws {
        // given

        let wallet = AccountGenerator.generateMetaAccount()

        let chainId = "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d"
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        // when

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId),
            let chain = chainRegistry.getChain(for: chainId),
            let account = wallet.fetch(for: chain.accountRequest())
        else {
            XCTFail("Can't find chain \(chainId)")
            return
        }

        let remoteRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let operationQueue = OperationQueue()

        let executionTimeWrapper = ParaStkYieldBoostOperationFactory().createExecutionTimeOperation(
            for: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: remoteRequestFactory,
            periodInDays: period
        )

        operationQueue.addOperations(executionTimeWrapper.allOperations, waitUntilFinished: true)

        let executionTime = try executionTimeWrapper.targetOperation.extractNoCancellableResultData()

        let senderResolutionFactory = ExtrinsicSenderResolutionFactoryStub(accountId: delegator, chain: chain)

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chainId)

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: UserDataStorageTestFacade(),
            substrateStorageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        extrinsicService = ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeProvider,
            senderResolvingFactory: senderResolutionFactory,
            metadataHashOperationFactory: MetadataHashOperationFactory(
                metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: storageFacade),
                operationQueue: operationQueue
            ),
            nonceOperationFactory: TransactionNonceOperationFactory(),
            feeEstimationRegistry: feeEstimationRegistry,
            extensions: signedExtensionFactory.createExtensions(),
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let call = AutomationTime.ScheduleAutocompoundCall(
            executionTime: executionTime,
            frequency: AutomationTime.Seconds(TimeInterval(period).secondsFromDays),
            collatorId: collator,
            accountMinimum: accountMinimum
        )

        var feeResult: FeeExtrinsicResult?

        let expectation = XCTestExpectation()

        extrinsicService?.estimateFee(
            { builder in
                try builder.adding(call: call.runtimeCall)
            },
            runningIn: .main
        ) { result in
            feeResult = result

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 20.0)

        // then

        switch feeResult {
        case let .success(dispatchInfo):
            Logger.shared.info("Schedule autocompound dispatch info: \(dispatchInfo)")
        case let .failure(error):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTFail("Unexpected empty result")
        }
    }

    private func performCancelTaskFeeEstimation(for taskId: AutomationTime.TaskId) {
        // given

        let wallet = AccountGenerator.generateMetaAccount()

        let chainId = "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d"
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        // when

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let chain = chainRegistry.getChain(for: chainId),
            let account = wallet.fetch(for: chain.accountRequest())
        else {
            XCTFail("Can't find chain \(chainId)")
            return
        }

        let senderResolutionFactory = ExtrinsicSenderResolutionFactoryStub(
            accountId: AccountId.random(of: chain.accountIdSize)!,
            chain: chain
        )

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chainId)

        let operationQueue = OperationQueue()

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            userStorageFacade: UserDataStorageTestFacade(),
            substrateStorageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        extrinsicService = ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeService,
            senderResolvingFactory: senderResolutionFactory,
            metadataHashOperationFactory: MetadataHashOperationFactory(
                metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: storageFacade),
                operationQueue: operationQueue
            ),
            nonceOperationFactory: TransactionNonceOperationFactory(),
            feeEstimationRegistry: feeEstimationRegistry,
            extensions: signedExtensionFactory.createExtensions(),
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        var feeResult: FeeExtrinsicResult?

        let expectation = XCTestExpectation()

        let call = AutomationTime.CancelTaskCall(taskId: taskId)

        extrinsicService?.estimateFee(
            { builder in
                try builder.adding(call: call.runtimeCall)
            },
            runningIn: .main
        ) { result in
            feeResult = result

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 20.0)

        // then

        switch feeResult {
        case let .success(dispatchInfo):
            Logger.shared.info("Cancel task dispatch info: \(dispatchInfo)")
        case let .failure(error):
            XCTFail("Unexpected error: \(error)")
        case .none:
            XCTFail("Unexpected empty result")
        }
    }

    private func perforExecutionTimeTest(for period: UInt) {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d"

        // when

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Can't find connection")
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            XCTFail("Can't find runtime provider")
            return
        }

        let remoteRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let wrapper = ParaStkYieldBoostOperationFactory().createExecutionTimeOperation(
            for: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: remoteRequestFactory,
            periodInDays: period
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let timestamp = try wrapper.targetOperation.extractNoCancellableResultData()

            let currentTime = AutomationTime.UnixTime(Date().timeIntervalSince1970)
            let isValid = timestamp > currentTime && (timestamp % AutomationTime.Seconds(TimeInterval.secondsInHour) == 0)

            XCTAssertTrue(isValid)

            Logger.shared.info("Execution time: \(timestamp)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
