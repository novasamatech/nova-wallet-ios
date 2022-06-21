import XCTest
@testable import novawallet
import BigInt
import RobinHood

class XcmTransfersFeeTests: XCTestCase {
    func testFeeCalculation() {
        do {
            // given
            let originChainId = "baf5aabe40646d11f0ee8abbdc64f4a4b7674925cba08e4a05ff9ebed6e2126b"
            let destinationChainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
            let destinationParaId: ParaId? = 2023
            let assetId: AssetModel.Id = 4
            let beneficiaryAddress = "0x44625b6a493ec6e00166fc21ff7a1ee07eb8ee4a"
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

            let beneficiary = try beneficiaryAddress.toAccountId()
            let destination = XcmAssetDestination(
                chain: destinationChain,
                parachainId: destinationParaId,
                accountId: beneficiary
            )

            let feeMessages = try xcmTransferFactory.createWeightMessages(
                from: originChainAsset,
                reserve: reserve,
                destination: destination,
                amount: amount,
                xcmTransfers: xcmTransfers
            )

            let destinationBaseWeight = xcmTransfers.baseWeight(for: destinationChainId) ?? 0
            let destinationWeight = destinationBaseWeight * BigUInt(feeMessages.destination.instructionsCount)
            let destinationFee = try estimateFee(
                for: feeMessages.destination,
                chain: destinationChain,
                chainRegistry: chainRegistry,
                maxWeight: destinationWeight
            )

            Logger.shared.info("Fee in \(destinationChainId): \(destinationFee)")

            if let reserveFeeMessage = feeMessages.reserve {
                let reserveFee = try estimateFee(
                    for: reserveFeeMessage,
                    chain: reserveChain,
                    chainRegistry: chainRegistry
                )

                Logger.shared.info("Fee in \(reserveChain.chainId): \(reserveFee)")
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func estimateFee(
        for message: Xcm.Message,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        maxWeight: BigUInt
    ) throws -> RuntimeDispatchInfo {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let accountId: AccountId
        let cryptoType: MultiassetCryptoType

        if chain.isEthereumBased {
            accountId = AccountId.dummyAccountId(of: 20)
            cryptoType = .ethereumEcdsa
        } else {
            accountId = AccountId.dummyAccountId(of: 32)
            cryptoType = .sr25519
        }

        let extrinsicService = ExtrinsicService(
            accountId: accountId,
            chain: chain,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationManager: OperationManager()
        )

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let call = Xcm.ExecuteCall(message: message, maxWeight: maxWeight)
            return try builder.adding(call: call.runtimeCall)
        }

        var feeResult: Result<RuntimeDispatchInfo, Error>?

        let semaphore = DispatchSemaphore(value: 0)

        extrinsicService.estimateFee(builderClosure,runningIn: .global()) { result in
            feeResult = result

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + .seconds(60))

        switch feeResult {
        case let .success(info):
            return info
        case let .failure(error):
            throw error
        case .none:
            throw CommonError.undefined
        }
    }
}
