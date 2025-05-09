import XCTest
@testable import novawallet
import Keystore_iOS

final class RaiseOperationFactoryTest: XCTestCase {
    static let chainId = KnowChainId.westend
    
    var customerProvider: RaiseCustomerProviding!
    
    func testFetchBrands() {
        do {
            let brands = try fetchBrands(for: nil, pageIndex: 0, pageSize: 25)
            
            Logger.shared.info("Brands: \(brands)")
            
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testSearchBrands() {
        do {
            let brands = try fetchBrands(for: "coffee", pageIndex: 0, pageSize: 25)
            
            Logger.shared.info("Brands: \(brands)")
            
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testFetchCryptoAssets() {
        do {
            let operationQueue = OperationQueue()
            let (authProvider, _) = try createAuthProvider(for: operationQueue)
            let operationFactory = RaiseOperationFactory(
                authProvider: authProvider,
                customerProvider: customerProvider,
                operationQueue: operationQueue
            )
            
            let cryptoAssetsWrapper = operationFactory.createCryptoAssetsWrapper()
            
            operationQueue.addOperations(cryptoAssetsWrapper.allOperations, waitUntilFinished: true)
            
            let cryptoAssets = try cryptoAssetsWrapper.targetOperation.extractNoCancellableResultData()
            
            Logger.shared.debug("Crypto Assets: \(cryptoAssets)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testTransactionCreation() {
        do {
            let operationQueue = OperationQueue()
            let (authProvider, _) = try createAuthProvider(for: operationQueue)
            let operationFactory = RaiseOperationFactory(
                authProvider: authProvider,
                customerProvider: customerProvider,
                operationQueue: operationQueue
            )
            
            let transactionWrapper = operationFactory.createTransaction(
                for: RaiseTransactionRequestInfo(
                    orderId: UUID().uuidString,
                    brandId: "8b188182-5353-4a07-9a05-af8db8a21b76",
                    paymentToken: ChainAssetId(chainId: Self.chainId, assetId: AssetModel.utilityAssetId),
                    amount: 10000
                )
            )
            
            operationQueue.addOperations(transactionWrapper.allOperations, waitUntilFinished: true)
            
            let transaction = try transactionWrapper.targetOperation.extractNoCancellableResultData()
            
            Logger.shared.debug("Transaction: \(transaction)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    private func fetchBrands(for query: String?, pageIndex: Int, pageSize: Int) throws -> RaiseListResult<RaiseBrandAttributes> {
        let operationQueue = OperationQueue()
        let (authProvider, _) = try createAuthProvider(for: operationQueue)
        let operationFactory = RaiseOperationFactory(
            authProvider: authProvider,
            customerProvider: customerProvider,
            operationQueue: operationQueue
        )
        
        let info = RaiseBrandsRequestInfo(query: query, pageIndex: pageIndex, pageSize: pageSize)
        let brandsWrapper = operationFactory.createBrandsWrapper(for: info)
        
        operationQueue.addOperations(brandsWrapper.allOperations, waitUntilFinished: true)
        
        return try brandsWrapper.targetOperation.extractNoCancellableResultData()
    }
    
    private func createAuthProvider(for operationQueue: OperationQueue) throws -> (RaiseAuthProviding, RaiseAuthKeyStorageProtocol) {
        let keystore = InMemoryKeychain()
        let userStorageFacade = UserDataStorageTestFacade()
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        let walletSettings = SelectedWalletSettings(
            storageFacade: userStorageFacade,
            operationQueue: operationQueue
        )
        
        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keystore,
            settings: walletSettings
        )
        
        let chain = try chainRegistry.getChainOrError(for: Self.chainId)
        
        let account = try walletSettings.value.fetchOrError(for: chain.accountRequest())
        
        customerProvider = RaiseWalletCustomerProvider(account: account)

        let authStore = RaiseAuthKeyStorage(
            keystore: keystore,
            account: account
        )
        
        let authFactory = RaiseAuthFactory(
            keystore: authStore,
            customerProvider: customerProvider,
            operationQueue: operationQueue
        )
        
        let authProvider = RaiseAuthProvider(
            authFactory: authFactory,
            authStore: authStore,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
        
        return (authProvider, authStore)
    }
}
