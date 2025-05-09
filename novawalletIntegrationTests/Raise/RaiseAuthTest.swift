import XCTest
@testable import novawallet
import Keystore_iOS

final class RaiseAuthTest: XCTestCase {
    static let chainId = KnowChainId.westend
    
    var keystore: KeystoreProtocol!
    var operationQueue: OperationQueue!
    var walletSettings: SelectedWalletSettings!
    var chain: ChainModel!
                                                    
    override func setUp() async throws {
        keystore = InMemoryKeychain()
        operationQueue = OperationQueue()
        
        let userStorageFacade = UserDataStorageTestFacade()
        walletSettings = SelectedWalletSettings(
            storageFacade: userStorageFacade,
            operationQueue: operationQueue
        )
        
        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keystore,
            settings: walletSettings
        )
        
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        chain = try chainRegistry.getChainOrError(for: Self.chainId)
    }

    func testAuthTokenReceive() {
        do {
            let account = try walletSettings.value.fetchOrError(for: chain.accountRequest())
            let customerProvider = RaiseWalletCustomerProvider(account: account)
            
            let authStore = RaiseAuthKeyStorage(
                keystore: keystore,
                account: account
            )
            
            let authFactory = RaiseAuthFactory(
                keystore: authStore,
                customerProvider: customerProvider,
                operationQueue: operationQueue
            )
            
            // when
            
            let authWrapper = authFactory.createAuthTokenRequest()
            
            operationQueue.addOperations(authWrapper.allOperations, waitUntilFinished: true)
            
            // then
            
            let response = try authWrapper.targetOperation.extractNoCancellableResultData()
            
            Logger.shared.info("Auth token: \(response)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testRefreshToken() {
        do {
            let account = try walletSettings.value.fetchOrError(for: chain.accountRequest())
            let customerProvider = RaiseWalletCustomerProvider(account: account)
            
            let authStore = RaiseAuthKeyStorage(
                keystore: keystore,
                account: account
            )
            
            let authFactory = RaiseAuthFactory(
                keystore: authStore,
                customerProvider: customerProvider,
                operationQueue: operationQueue
            )
            
            // when
            
            let authOperation = authFactory.createRefreshTokenRequest(
                for: ""
            )
            
            operationQueue.addOperations([authOperation], waitUntilFinished: true)
            
            // then
            
            let response = try authOperation.extractNoCancellableResultData()
            
            Logger.shared.info("Auth token: \(response)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }
}
