import XCTest
@testable import novawallet

final class Pdc20OperationTests: XCTestCase {
    func testPolkadot() {
        let address = "157oamQLvyR33mY3isu3wrCTx1DYGGzHTgCt9oUp9WAp8ivS"

        do {
            let response = try performQuery(for: address)
            Logger.shared.info("\(response)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    private func performQuery(for address: String) throws -> Pdc20NftResponse {
        let operationFactory = Pdc20NftOperationFactory(url: Pdc20Api.url)
        let operationQueue = OperationQueue()

        let wrapper = operationFactory.fetchNfts(for: address, network: Pdc20Api.polkadotNetwork)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
