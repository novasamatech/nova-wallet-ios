import XCTest
@testable import novawallet
import BigInt
import RobinHood

class XcmTransfersFeeTests: XCTestCase {
    func testKaruraMoonriverBnc() throws {
        let originChainId = "baf5aabe40646d11f0ee8abbdc64f4a4b7674925cba08e4a05ff9ebed6e2126b"
        let destinationChainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        let assetId: AssetModel.Id = 4
        let beneficiary = AccountId.dummyAccountId(of: 20)
        let amount: BigUInt = 1_000_000_000

        let transferDestinationId = XcmTransferDestinationId(
            chainId: destinationChainId,
            accountId: beneficiary
        )

        performTestFeeCalculation(
            originChainAssetId: ChainAssetId(chainId: originChainId, assetId: assetId),
            transferDestinationId: transferDestinationId,
            amount: amount
        )
    }

    func testMoonriverKusama() throws {
        let originChainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        let destinationChainId = "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        let assetId: AssetModel.Id = 2
        let beneficiary = AccountId.dummyAccountId(of: 32)
        let amount: BigUInt = 1_000_000_000_00

        let transferDestinationId = XcmTransferDestinationId(
            chainId: destinationChainId,
            accountId: beneficiary
        )

        performTestFeeCalculation(
            originChainAssetId: ChainAssetId(chainId: originChainId, assetId: assetId),
            transferDestinationId: transferDestinationId,
            amount: amount
        )
    }

    func testMoonriverKarura() throws {
        let originChainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        let destinationChainId = "baf5aabe40646d11f0ee8abbdc64f4a4b7674925cba08e4a05ff9ebed6e2126b"
        let assetId: AssetModel.Id = 4
        let beneficiary = AccountId.dummyAccountId(of: 32)
        let amount: BigUInt = 1_000_000_000_00

        let transferDestinationId = XcmTransferDestinationId(
            chainId: destinationChainId,
            accountId: beneficiary
        )

        performTestFeeCalculation(
            originChainAssetId: ChainAssetId(chainId: originChainId, assetId: assetId),
            transferDestinationId: transferDestinationId,
            amount: amount
        )
    }

    func performTestFeeCalculation(
        originChainAssetId: ChainAssetId,
        transferDestinationId: XcmTransferDestinationId,
        amount: BigUInt
    ) {
        do {
            // given
            let storageFacade = SubstrateStorageTestFacade()
            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

            let remoteUrl = ApplicationConfig.shared.xcmTransfersURL
            let xcmTransfers = try XcmTransfersSyncService.setupForIntegrationTest(for: remoteUrl)

            let parties = try resolveParties(
                from: originChainAssetId,
                transferDestinationId: transferDestinationId,
                xcmTransfers: xcmTransfers,
                chainRegistry: chainRegistry
            )

            let wallet = MetaAccountModel(
                metaId: UUID().uuidString,
                name: "Test",
                substrateAccountId: AccountId.dummyAccountId(of: 32),
                substrateCryptoType: 0,
                substratePublicKey: Data.random(of: 32)!,
                ethereumAddress: AccountId.dummyAccountId(of: 20),
                ethereumPublicKey: Data.random(of: 33)!,
                chainAccounts: Set()
            )

            let destinationFee = try estimateFees(
                for: wallet,
                parties: parties,
                xcmTransfers: xcmTransfers,
                chainRegistry: chainRegistry,
                amount: amount,
                isForDestination: true
            )

            Logger.shared.info("Fee for destination: \(destinationFee)")

            let reserveChainId = parties.reserve.chain.chainId
            if reserveChainId != originChainAssetId.chainId, reserveChainId != transferDestinationId.chainId {
                let reserveFee = try estimateFees(
                    for: wallet,
                    parties: parties,
                    xcmTransfers: xcmTransfers,
                    chainRegistry: chainRegistry,
                    amount: amount,
                    isForDestination: false
                )

                Logger.shared.info("Fee for reserve: \(reserveFee)")
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func resolveParties(
        from origin: ChainAssetId,
        transferDestinationId: XcmTransferDestinationId,
        xcmTransfers: XcmTransfers,
        chainRegistry: ChainRegistryProtocol
    ) throws -> XcmTransferParties {
        let service = XcmTransferResolutionService(
            chainRegistry: chainRegistry,
            operationQueue: OperationQueue()
        )

        let semaphore = DispatchSemaphore(value: 0)

        var partiesResult: XcmTrasferResolutionResult?

        service.resolveTransferParties(
            for: origin,
            transferDestinationId: transferDestinationId,
            xcmTransfers: xcmTransfers,
            runningIn: .global()
        ) { result in
            partiesResult = result
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + .seconds(60))

        switch partiesResult {
        case let .success(parties):
            return parties
        case let .failure(error):
            throw error
        case .none:
            throw BaseOperationError.parentOperationCancelled
        }
    }

    private func estimateFees(
        for wallet: MetaAccountModel,
        parties: XcmTransferParties,
        xcmTransfers: XcmTransfers,
        chainRegistry: ChainRegistryProtocol,
        amount: BigUInt,
        isForDestination: Bool
    ) throws -> FeeWithWeight {
        let service = XcmTransferService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            operationQueue: OperationQueue()
        )

        let semaphore = DispatchSemaphore(value: 0)

        var feeResult: XcmTrasferFeeResult?

        let request = XcmTransferRequest(
            origin: parties.origin,
            destination: parties.destination,
            reserve: parties.reserve,
            amount: amount
        )

        if isForDestination {
            service.estimateDestinationTransferFee(
                request: request,
                xcmTransfers: xcmTransfers,
                runningIn: .global()
            ) { result in
                feeResult = result
                semaphore.signal()
            }
        } else {
            service.estimateReserveTransferFee(
                request: request,
                xcmTransfers: xcmTransfers,
                runningIn: .global()
            ) { result in
                feeResult = result
                semaphore.signal()
            }
        }

        _ = semaphore.wait(timeout: .now() + .seconds(60))

        switch feeResult {
        case let .success(parties):
            return parties
        case let .failure(error):
            throw error
        case .none:
            throw BaseOperationError.parentOperationCancelled
        }
    }
}
