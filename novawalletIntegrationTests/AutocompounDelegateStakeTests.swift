import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

class AutocompounDelegateStakeTests: XCTestCase {
    func testFetchExtrinsicParams() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "0f62b701fb12d02237a33b84818c11f621653d2b1614c777973babf4652b535d"

        let request = ParaStkYieldBoostRequest(
            amountToStake: 1000000000000,
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
            account: accountId
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

    private func perforExecutionTimeTest(for period: Int) {
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

            let currentTime = AutomationTime.Seconds(Date().timeIntervalSince1970)
            let isValid = timestamp > currentTime && (timestamp % AutomationTime.Seconds(TimeInterval.secondsInHour) == 0)

            XCTAssertTrue(isValid)

            Logger.shared.info("Execution time: \(timestamp)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
