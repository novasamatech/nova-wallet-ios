import XCTest
@testable import novawallet
import SubstrateSdk
import Operation_iOS
import NovaCrypto
import BigInt
import xxHash_Swift
import Keystore_iOS
import Foundation_iOS

final class ProxyOperationFactoryTests: XCTestCase {
    
    func testFetching() {
        let chainId = KnowChainId.kusama
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        
        let queue = OperationQueue()
        let operationFactory = ProxyOperationFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: queue)
        )
        let wrapper = operationFactory.fetchProxyList(requestFactory: storageRequestFactory,
                                                      connection: connection,
                                                      runtimeProvider: runtimeService,
                                                      at: nil)
        
        queue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: true
        )
        
        do {
            let result = try wrapper.targetOperation.extractNoCancellableResultData()
            if !result.isEmpty {
                Logger.shared.info("Fetched \(result.count) proxies")
            } else {
                XCTFail("Can't get any proxies")
            }
        } catch {
            XCTFail(error.localizedDescription)
        }

    }
}

