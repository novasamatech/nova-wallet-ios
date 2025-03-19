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
        let dryRunOperationFactory = DryRunOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
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
        
        let callDeriver = XcmCallDerivator(chainRegistry: chainRegistry)
        
        let callWrapper = callDeriver.createTransferCallDerivationWrapper(
            for: request,
            maxWeight: BigUInt(UInt64.max)
        )
        
        operationQueue.addOperations(callWrapper.allOperations, waitUntilFinished: true)
        
        let callCollecting = try callWrapper.targetOperation.extractNoCancellableResultData()
        
        var callBuilder: RuntimeCallBuilding = RuntimeCallBuilder()
        
        callBuilder = try callCollecting
            .addingToCall(builder: callBuilder)
            .dispatchingAs(.system(.signed(accountId)))
        
        let dryRunCall = try callBuilder
            .addingFirst(
                BalancesPallet.ForceSetBalance(
                    who: .accoundId(accountId),
                    newFree: 2 * amount
                ).runtimeCall()
            )
            .batching(.batchAll)
            .build()
        
        let dryRunCallWrapper = dryRunOperationFactory.createDryRunCallWrapper(
            dryRunCall,
            origin: .system(.root),
            chainId: polkadot.chainId
        )
        
        operationQueue.addOperations(dryRunCallWrapper.allOperations, waitUntilFinished: true)
        
        let dryRunCallResult = try dryRunCallWrapper.targetOperation.extractNoCancellableResultData()
        
        Logger.shared.debug("Dry run call: \(dryRunCallResult)")
        
        guard case let .success(callEffects) = dryRunCallResult else {
            XCTFail("call dry run failed")
            return
        }
        
        let dryRunXcmWrapper = dryRunOperationFactory.createDryRunXcmWrapper(
            from: Xcm.VersionedMultilocation.V3(
                .init(
                    parents: 1,
                    interior: .init(items: [])
                )
            ),
            xcm: callEffects.forwardedXcms[0].messages[0],
            chainId: hydration.chainId
        )
        
        operationQueue.addOperations(dryRunXcmWrapper.allOperations, waitUntilFinished: true)
        
        let dryRunXcmResult = try dryRunXcmWrapper.targetOperation.extractNoCancellableResultData()
        
        Logger.shared.debug("Dry run xcm: \(dryRunXcmResult)")
    }
}
