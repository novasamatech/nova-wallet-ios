import XCTest
@testable import novawallet
import BigInt

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
}
