import XCTest
@testable import novawallet
import RobinHood

final class HydraSwapsFeeTests: XCTestCase {
    
    func testNativeFee() {
        do {
            let address = "7HoFY1kmdfge15uRWtU6T5XZKsbxd97E3Ek1fi2xHbyqT2JD"
            
            let accountId = try address.toAccountId()
            
            let fee = try fetchSwapFee(
                for: address,
                callArgs: .init(
                    assetIn: .init(chainId: KnowChainId.hydra, assetId: 1),
                    amountIn: 10_000_000_000,
                    assetOut: .init(chainId: KnowChainId.hydra, assetId: 0),
                    amountOut: 199_000_000_000_000,
                    receiver: accountId,
                    direction: .sell,
                    slippage: SlippageConfig.defaultConfig.defaultSlippage,
                    context: nil
                ),
                feeAssetId: .init(chainId: KnowChainId.hydra, assetId: 0)
            )
            
            Logger.shared.info("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFeeInDot() {
        do {
            let address = "7HoFY1kmdfge15uRWtU6T5XZKsbxd97E3Ek1fi2xHbyqT2JD"
            
            let accountId = try address.toAccountId()
            
            let fee = try fetchSwapFee(
                for: address,
                callArgs: .init(
                    assetIn: .init(chainId: KnowChainId.hydra, assetId: 1),
                    amountIn: 10_000_000_000,
                    assetOut: .init(chainId: KnowChainId.hydra, assetId: 0),
                    amountOut: 199_000_000_000_000,
                    receiver: accountId,
                    direction: .sell,
                    slippage: SlippageConfig.defaultConfig.defaultSlippage,
                    context: nil
                ),
                feeAssetId: .init(chainId: KnowChainId.hydra, assetId: 1)
            )
            
            Logger.shared.info("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func fetchSwapFee(
        for address: AccountAddress,
        callArgs: AssetConversion.CallArgs,
        feeAssetId: ChainAssetId
    ) throws -> AssetConversion.FeeModel {
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        let chainId = feeAssetId.chainId
        
        let operationQueue = OperationQueue()
        
        let accountId = try address.toAccountId()
        
        let wallet = AccountGenerator.createWatchOnly(for: accountId)
        
        let userFacade = UserDataStorageTestFacade()
        
        let saveOperation = AccountRepositoryFactory(storageFacade: userFacade).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        ).saveOperation({
            [wallet]
        }, { [] })
        
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
        
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let feeAsset = chain.asset(for: feeAssetId.assetId) else {
            throw ChainRegistryError.noChain(chainId)
        }
        
        let generalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateStorageTestFacade(),
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: Logger.shared
        )
        
        let feeService = try AssetConversionFlowFacade(
            wallet: wallet,
            chainRegistry: chainRegistry,
            userStorageFacade: userFacade,
            generalSubscriptonFactory: generalSubscriptionFactory,
            operationQueue: operationQueue
        ).createFeeService(for: chain)
        
        var feeResult: AssetConversion.FeeResult?
        
        let expectation = XCTestExpectation()
        
        feeService.calculate(
            in: ChainAsset(chain: chain, asset: feeAsset),
            callArgs: callArgs,
            runCompletionIn: .main
        ) { result in
            feeResult = result
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 600)
        
        switch feeResult {
        case let .success(fee):
            return fee
        case let .failure(error):
            throw error
        case .none:
            throw CommonError.undefined
        }
    }
}
