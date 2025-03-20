import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class DryRunBasedFeeTests: XCTestCase {
    func testDryRunTransferAssets() throws {
        // given
        
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        let operationQueue = OperationQueue()
        let feeService = XcmDynamicCrosschainFeeCalculator(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
        
        let polkadot = try chainRegistry.getChainOrError(for: KnowChainId.polkadot)
        let dotPolkadot = polkadot.utilityChainAsset()!
        
        let amount = Decimal(2).toSubstrateAmount(
            precision: dotPolkadot.assetDisplayInfo.assetPrecision
        )!
        
        let accountId = Data.random(of: polkadot.accountIdSize)!
        
        let hydration = try chainRegistry.getChainOrError(for: KnowChainId.hydra)
        let transfers = try XcmTransfersSyncService.setupForIntegrationTest(for: ApplicationConfig.shared)
        
        let transferResolver = XcmTransferResolutionFactory(
            chainRegistry: chainRegistry,
            paraIdOperationFactory: ParaIdOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )
        )
        
        let transferResolutionWrapper = transferResolver.createResolutionWrapper(
            for: dotPolkadot.chainAssetId,
            transferDestinationId: XcmTransferDestinationId(
                chainId: hydration.chainId,
                accountId: accountId
            ),
            xcmTransfers: transfers
        )
        
        operationQueue.addOperations(
            transferResolutionWrapper.allOperations,
            waitUntilFinished: true
        )
        
        let transferParties = try transferResolutionWrapper.targetOperation.extractNoCancellableResultData()
        
        let request = XcmUnweightedTransferRequest(
            origin: transferParties.origin,
            destination: transferParties.destination,
            reserve: transferParties.reserve,
            metadata: transferParties.metadata,
            amount: amount
        )
        
        let feeWrapper = feeService.crossChainFeeWrapper(request: request)
        
        operationQueue.addOperations(feeWrapper.allOperations, waitUntilFinished: true)
        
        let fee = try feeWrapper.targetOperation.extractNoCancellableResultData()
        
        Logger.shared.debug("Fee: \(fee)")
    }
}
