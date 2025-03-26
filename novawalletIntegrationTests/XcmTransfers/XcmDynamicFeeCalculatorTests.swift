import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class XcmDynamicFeeCalculatorTests: XCTestCase {
    func testDOTPolkadotHydration() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.polkadot,
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.hydra,
                destinationAssetSymbol: "DOT"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDOTPolkadotPolkadotAssetHub() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.polkadot,
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.polkadotAssetHub,
                destinationAssetSymbol: "DOT"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDOTPolkadotAssetHubPolkadot() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.polkadotAssetHub,
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.polkadot,
                destinationAssetSymbol: "DOT"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDOTHydraMoonbeam() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.hydra,
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.moonbeam,
                destinationAssetSymbol: "xcDOT"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDOTMoonbeamHydra() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.moonbeam,
                originAssetSymbol: "xcDOT",
                destinationChainId: KnowChainId.hydra,
                destinationAssetSymbol: "DOT"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDOTAstarHydra() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.astar,
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.hydra,
                destinationAssetSymbol: "DOT"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testUSDTAssetHubHydra() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.polkadotAssetHub,
                originAssetSymbol: "USDT",
                destinationChainId: KnowChainId.hydra,
                destinationAssetSymbol: "USDT"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testWNDWestendWestmint() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.westend,
                originAssetSymbol: "WND",
                destinationChainId: KnowChainId.westmint,
                destinationAssetSymbol: "WND"
            )
            
            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    private func calculateFee(
        for originChainId: ChainModel.Id,
        originAssetSymbol: String,
        destinationChainId: ChainModel.Id,
        destinationAssetSymbol: String
    ) throws -> XcmFeeModelProtocol {
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        let operationQueue = OperationQueue()
        let feeService = XcmDynamicCrosschainFeeCalculator(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
        
        let originChain = try chainRegistry.getChainOrError(for: originChainId)
        let originChainAsset = try originChain.chainAssetForSymbolOrError(originAssetSymbol)
        let destinationChain = try chainRegistry.getChainOrError(for: destinationChainId)
        let destinationChainAsset = try destinationChain.chainAssetForSymbolOrError(destinationAssetSymbol)
        
        let destinationAccountId = Data.random(of: destinationChain.accountIdSize)!
        
        let transfers = try XcmTransfersSyncService.setupForIntegrationTest(for: ApplicationConfig.shared)
        
        let transferResolver = XcmTransferResolutionFactory(
            chainRegistry: chainRegistry,
            paraIdOperationFactory: ParaIdOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )
        )
        
        let transferResolutionWrapper = transferResolver.createResolutionWrapper(
            for: originChainAsset.chainAssetId,
            transferDestinationId: XcmTransferDestinationId(
                chainAssetId: destinationChainAsset.chainAssetId,
                accountId: destinationAccountId
            ),
            xcmTransfers: transfers
        )
        
        operationQueue.addOperations(
            transferResolutionWrapper.allOperations,
            waitUntilFinished: true
        )
        
        let transferParties = try transferResolutionWrapper.targetOperation.extractNoCancellableResultData()
        
        let amount = Decimal(1).toSubstrateAmount(precision: originChainAsset.assetDisplayInfo.assetPrecision)!
        
        let request = XcmUnweightedTransferRequest(
            origin: transferParties.origin,
            destination: transferParties.destination,
            reserve: transferParties.reserve,
            metadata: transferParties.metadata,
            amount: amount
        )
        
        let feeWrapper = feeService.crossChainFeeWrapper(request: request)
        
        operationQueue.addOperations(feeWrapper.allOperations, waitUntilFinished: true)
        
        return try feeWrapper.targetOperation.extractNoCancellableResultData()
    }
}
