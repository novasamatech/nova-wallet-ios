import XCTest
@testable import novawallet
import BigInt

class XcmTransfersFeeTests: XCTestCase {
    func testFeeCalculation() {
        do {
            // given
            let originChainId = "baf5aabe40646d11f0ee8abbdc64f4a4b7674925cba08e4a05ff9ebed6e2126b"
            let destinationChainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
            let destinationParaId: ParaId? = 2023
            let assetId: AssetModel.Id = 4
            let benificiaryAddress = "0x44625b6a493ec6e00166fc21ff7a1ee07eb8ee4a"
            let amount: BigUInt = 1_000_000_000
            let reserveParaId: ParaId? = 2001

            let storageFacade = SubstrateStorageTestFacade()
            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

            let remoteUrl = ApplicationConfig.shared.xcmTransfersURL
            let xcmTransfers = try XcmTransfersSyncService.setupForIntegrationTest(for: remoteUrl)

            guard let originChain = chainRegistry.getChain(for: originChainId) else {
                XCTFail("Origin chain is missing")
                return
            }

            guard let asset = originChain.assets.first(where: { $0.assetId == assetId }) else {
                XCTFail("Invalid asset")
                return
            }

            let originChainAsset = ChainAsset(chain: originChain, asset: asset)

            guard let destinationChain = chainRegistry.getChain(for: destinationChainId) else {
                XCTFail("Destination chain is missing")
                return
            }

            guard
                let reserveChainId = xcmTransfers.getReserveTransfering(from: originChainId, assetId: assetId) else {
                XCTFail("Reserve is undefined")
                return
            }

            guard let reserveChain = chainRegistry.getChain(for: reserveChainId) else {
                XCTFail("Reserve chain is missing")
                return
            }

            let xcmTransferFactory = XcmTransferFactory()

            let reserve = XcmAssetReserve(chain: reserveChain, parachainId: reserveParaId)

            let benificiary = try benificiaryAddress.toAccountId()
            let destination = XcmAssetDestination(
                chain: destinationChain,
                parachainId: destinationParaId,
                accountId: benificiary
            )

            let feeMessages = try xcmTransferFactory.createWeightMessages(
                from: originChainAsset,
                reserve: reserve,
                destination: destination,
                amount: amount,
                xcmTransfers: xcmTransfers
            )

            Logger.shared.info("\(feeMessages)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
