import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt

final class XcmExecuteFeeCalculatorTests: XCTestCase {
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

    func testDOTHydrationPolkadot() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.hydra,
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.polkadot,
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

    func testDOTBifrostHydra() throws {
        do {
            let fee = try calculateFee(
                for: "262e1b2ad728475fd6fe88e62d34c200abe6fd693931ddad144059b1eb884e5b",
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

    func testMythMythosHydration() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.mythos,
                originAssetSymbol: "MYTH",
                destinationChainId: KnowChainId.hydra,
                destinationAssetSymbol: "MYTH"
            )

            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMythPAHMythos() throws {
        do {
            let fee = try calculateFee(
                for: KnowChainId.polkadotAssetHub,
                originAssetSymbol: "MYTH",
                destinationChainId: KnowChainId.mythos,
                destinationAssetSymbol: "MYTH"
            )

            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDOTCollectivesPAH() throws {
        do {
            let fee = try calculateFee(
                for: "46ee89aa2eedd13e988962630ec9fb7565964cf5023bb351f2b6b25c1b68b0b2",
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.polkadotAssetHub,
                destinationAssetSymbol: "DOT"
            )

            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDOTCollectivesBridgeHub() throws {
        do {
            let fee = try calculateFee(
                for: "46ee89aa2eedd13e988962630ec9fb7565964cf5023bb351f2b6b25c1b68b0b2",
                originAssetSymbol: "DOT",
                destinationChainId: "dcf691b5a3fbe24adc99ddc959c0561b973e329b1aef4c4b22e7bb2ddecb4464",
                destinationAssetSymbol: "DOT"
            )

            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDOTBridgeHubCollectives() throws {
        do {
            let fee = try calculateFee(
                for: "dcf691b5a3fbe24adc99ddc959c0561b973e329b1aef4c4b22e7bb2ddecb4464",
                originAssetSymbol: "DOT",
                destinationChainId: "46ee89aa2eedd13e988962630ec9fb7565964cf5023bb351f2b6b25c1b68b0b2",
                destinationAssetSymbol: "DOT"
            )

            Logger.shared.debug("Fee: \(fee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDOTBridgeHubPAH() throws {
        do {
            let fee = try calculateFee(
                for: "dcf691b5a3fbe24adc99ddc959c0561b973e329b1aef4c4b22e7bb2ddecb4464",
                originAssetSymbol: "DOT",
                destinationChainId: KnowChainId.polkadotAssetHub,
                destinationAssetSymbol: "DOT"
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
            callDerivator: XcmExecuteDerivator(
                chainRegistry: chainRegistry,
                xcmPaymentFactory: XcmPaymentOperationFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                ),
                metadataFactory: XcmPalletMetadataQueryFactory()
            ),
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
