import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS

final class HydrationCommissionBeneficiaryTests: XCTestCase {
    func testBeneficiaryReadinessForEveryHydrationAsset() throws {
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        let operationQueue = OperationQueue()

        guard let hydra = chainRegistry.getChain(for: KnowChainId.hydra) else {
            XCTFail("No Hydration chain in chains.json")
            return
        }

        let beneficiary = try AssetExchangeCommissionConstants.hydrationBeneficiaryAddress.toAccountId()

        let provider = AssetExchangeCommissionBeneficiaryProvider(
            beneficiary: beneficiary,
            balanceQueryFactory: WalletRemoteQueryWrapperFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            assetStorageInfoFactory: AssetStorageInfoOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        var established: [String] = []
        var dark: [String] = []

        for asset in hydra.assets {
            let chainAsset = ChainAsset(chain: hydra, asset: asset)
            let wrapper = provider.fetchStateWrapper(for: chainAsset)

            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

            do {
                let state = try wrapper.targetOperation.extractNoCancellableResultData()
                let line = "\(asset.symbol): balance \(state.balance) ed \(state.existentialDeposit)"

                if state.canReceive {
                    established.append(line)
                } else {
                    dark.append(line)
                }
            } catch {
                XCTFail("Could not resolve beneficiary state for \(asset.symbol): \(error)")
            }
        }

        Logger.shared.info("Commission established (\(established.count)):")
        established.forEach { Logger.shared.info($0) }

        Logger.shared.info("Commission dark (\(dark.count)):")
        dark.forEach { Logger.shared.info($0) }
    }
}
