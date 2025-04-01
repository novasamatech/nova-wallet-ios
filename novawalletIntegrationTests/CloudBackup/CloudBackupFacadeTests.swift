import XCTest
@testable import novawallet
import Keystore_iOS
import NovaCrypto

final class CloudBackupFacadeTests: XCTestCase {
    func testSyncMetadataSaved() throws {
        let syncMetadataManager = CloudBackupSyncMetadataManager(
            settings: SettingsManager.shared,
            keystore: Keychain()
        )
        
        let password = "testPassword"
        try syncMetadataManager.enableBackup(for: password)
        
        XCTAssertTrue(syncMetadataManager.isBackupEnabled)
        XCTAssertEqual(password, try syncMetadataManager.getPassword())
        XCTAssertNotNil(syncMetadataManager.getLastSyncDate())
    }
    
    func testCreateBackup() {
        do {
            // given
            let keystore = InMemoryKeychain()
            let operationQueue = OperationQueue()
            
            let serviceFactory = ICloudBackupServiceFactory(
                containerId: CloudBackup.containerId
            )
            
            let facade = CloudBackupServiceFacade(
                serviceFactory: serviceFactory,
                operationQueue: operationQueue
            )
            
            // when
            
            let wallet = try createWalletUsingMnemonic(with: keystore, queue: operationQueue)
            let password = UUID().uuidString
            
            let expectation = XCTestExpectation()
            var operationResult: Result<Void, CloudBackupServiceFacadeError>?
            
            facade.createBackup(
                wallets: [wallet],
                keystore: keystore,
                password: password,
                runCompletionIn: .main
            ) { result in
                operationResult = result
                expectation.fulfill()
            }
            
            // then
            
            wait(for: [expectation], timeout: 10)
            
            switch operationResult {
            case .success:
                break
            case let .failure(error):
                XCTFail("Backup failed: \(error)")
            case .none:
                XCTFail("Unexpected empty result")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCheckCloudBackupExists() {
        // given
        let operationQueue = OperationQueue()
        
        let serviceFactory = ICloudBackupServiceFactory(
            containerId: CloudBackup.containerId
        )
        
        let facade = CloudBackupServiceFacade(
            serviceFactory: serviceFactory,
            operationQueue: operationQueue
        )
        
        // when
        
        let expectation = XCTestExpectation()
        var operationResult: Result<Bool, CloudBackupServiceFacadeError>?
        
        facade.checkBackupExists(runCompletionIn: .main) { result in
            operationResult = result
            expectation.fulfill()
        }
        
        // then
        
        wait(for: [expectation], timeout: 10)
        
        switch operationResult {
        case .success:
            break
        case let .failure(error):
            XCTFail("Backup check failed: \(error)")
        case .none:
            XCTFail("Unexpected empty result")
        }
    }
    
    private func createWalletUsingMnemonic(
        with keystore: KeystoreProtocol,
        queue: OperationQueue
    ) throws -> MetaAccountModel {
        let mnemonic = try IRMnemonicCreator().randomMnemonic(.entropy128)

        let newAccountRequest = MetaAccountCreationRequest(
            username: "test\(UInt.random(in: 1...UInt.max))",
            derivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519
        )
        
        let operationFactory = MetaAccountOperationFactory(keystore: keystore)
        let operation = operationFactory.newSecretsMetaAccountOperation(
            request: newAccountRequest,
            mnemonic: mnemonic
        )
        
        queue.addOperations([operation], waitUntilFinished: true)
        
        return try operation.extractNoCancellableResultData()
    }
}
