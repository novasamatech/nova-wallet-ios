import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class WalletRemoteQueryFactoryTests: XCTestCase {
    func testPolkadotExistingBalance() throws {
        do {
            let accountId = try "1ChFWeNRLarAPRCTM3bfJmncJbSAbSS9yqjueWz7jX7iTVZ".toAccountId()
            let balance = try performQuery(for: accountId, chainId: KnowChainId.polkadot)
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testPolkadotNotExistingBalance() throws {
        do {
            let accountId = try "123gpPmcSD3BjqXJboFNLT3ArShcsZ9veDdZnmiHNF3sNQng".toAccountId()
            let balance = try performQuery(for: accountId, chainId: KnowChainId.polkadot)
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testInterlayExistingBalance() throws {
        do {
            let accountId = try "wd7haPUigB22TB9HEKs2k2JrwBf1onbtdNXWZAXHnRN7FVHMf".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: "bf88efe70e9e0e916416e8bed61f2b45717f517d7f3523e33c7b001e5ffcbc72"
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testInterlayNotExistingBalance() throws {
        do {
            let accountId = try "wd8YZxMqvBtUnkbPLUKEWhT8KRo7zVZc7rmJP3eV5fse18stt".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: "bf88efe70e9e0e916416e8bed61f2b45717f517d7f3523e33c7b001e5ffcbc72"
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testEquilibriumExistingBalance() throws {
        do {
            let accountId = try "cg7h2eLBseFrAbdeZ4X1CHkiWybwwCfhxGBDhvrmFNUBuzs1o".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: "89d3ec46d2fb43ef5a9713833373d5ea666b092fa8fd68fbc34596036571b907"
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testEquilibriumNotExistingBalance() throws {
        do {
            let accountId = try "cg49kkSwuqAkkP2GZqq7tNRieU3y2wqrt6D89FsVcXAxyA8EN".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: "89d3ec46d2fb43ef5a9713833373d5ea666b092fa8fd68fbc34596036571b907"
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testMoonbeamExistingBalance() throws {
        do {
            let accountId = try "0x7aa98aeb3afacf10021539d5412c7ac6afe0fb00".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: KnowChainId.moonbeam
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testMoonbeamNotExistingBalance() throws {
        do {
            let accountId = try "0x7aa98aeb3afacf10021539d5412c7ac6afe0fc00".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: KnowChainId.moonbeam
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testStatemineExistingBalance() throws {
        do {
            let accountId = try "F53d3jeyFvb2eYsgAERhjC8mogao4Kg4GsdezrqiT8aj55v".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: KnowChainId.kusamaAssetHub,
                assetId: 7
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testStatemineNotExistingBalance() throws {
        do {
            let accountId = try "Cn1mVjBBvLJUWE8GQoeR7JduGt2GxhUXrx191ob3Si6HA9E".toAccountId()
            let balance = try performQuery(
                for: accountId,
                chainId: KnowChainId.kusamaAssetHub,
                assetId: 7
            )
            Logger.shared.info("Did receive: \(balance)")
        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    private func performQuery(for accountId: AccountId, chainId: ChainModel.Id, assetId: AssetModel.Id = 0) throws -> AssetBalance {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()
        
        let chain = try chainRegistry.getChainOrError(for: chainId)
        let chainAsset = try chain.chainAssetOrError(for: assetId)
        
        let operationFactory = WalletRemoteQueryWrapperFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        
        let queryWrapper = operationFactory.queryBalance(
            for: accountId,
            chainAsset: chainAsset
        )
        
        operationQueue.addOperations(queryWrapper.allOperations, waitUntilFinished: true)
        
        return try queryWrapper.targetOperation.extractNoCancellableResultData()
    }
}
