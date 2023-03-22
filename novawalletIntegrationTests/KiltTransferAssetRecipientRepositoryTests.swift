import XCTest
import RobinHood
@testable import novawallet
import SubstrateSdk

final class KiltTransferAssetRecipientRepositoryTests: XCTestCase {
    func testFetchAccounts() throws {
        let url = URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/test/kilt_web3names/tests/assets_web3names.json")!
        let repository = KiltTransferAssetRecipientRepository()
        let accountsOperation = repository.fetchRecipients(url: url)
        OperationQueue().addOperations(accountsOperation.allOperations, waitUntilFinished: true)
        let accounts = try accountsOperation.targetOperation.extractNoCancellableResultData()
        XCTAssertTrue(!accounts.isEmpty)
    }
}
