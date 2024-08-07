import XCTest
@testable import novawallet
import Operation_iOS

class EthereumBaseIntegrationTests: XCTestCase {
    func testTransactionReceiptFetch() {
        // given

        let chainId = "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"
        let transactionHash = "0x6350478650f0ad0771ddd5895c5bc9c86d575d047cd9a095ebbb8a8f029a39f6"

        // when

        do {
            let receipt = try fetchTransactionReceipt(for: chainId, txHash: transactionHash)

            XCTAssertNotNil(receipt?.fee)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransactionReceiptNullForInvalidHash() {
        // given

        let chainId = "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"
        let transactionHash = "0x6350478650f0ad1771ddd5895c5bc9c86d575d047cd9a095ebbb8a8f029a39f6"

        // when

        do {
            let receipt = try fetchTransactionReceipt(for: chainId, txHash: transactionHash)

            XCTAssertNil(receipt)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func fetchTransactionReceipt(for chainId: ChainModel.Id, txHash: String) throws -> EthereumTransactionReceipt? {
        let chainStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: chainStorageFacade)

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        let operation = operationFactory.createTransactionReceiptOperation(for: txHash)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }
}
