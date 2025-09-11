import Foundation
import Operation_iOS
import SubstrateSdk

enum XcmExecuteDerivatorError: Error {
    case messageWeightFailed(JSON)
}

final class XcmExecuteDerivator {
    let chainRegistry: ChainRegistryProtocol
    let xcmPaymentFactory: XcmPaymentOperationFactoryProtocol
    let metadataFactory: XcmPalletMetadataQueryFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        xcmPaymentFactory: XcmPaymentOperationFactoryProtocol,
        metadataFactory: XcmPalletMetadataQueryFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.xcmPaymentFactory = xcmPaymentFactory
        self.metadataFactory = metadataFactory
    }
}

private extension XcmExecuteDerivator {
    func half(asset: XcmUni.Asset) -> XcmUni.Asset {
        switch asset.fun {
        case let .fungible(amount):
            XcmUni.Asset(assetId: asset.assetId, amount: amount / 2)
        case .nonFungible:
            asset
        }
    }

    func localReserveTransferProgram(
        for transferRequest: XcmUnweightedTransferRequest
    ) throws -> XcmUni.Instructions {
        let originAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.destination.parachainId)

        let assetLocation = try XcmUni.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let destAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let destinationLocation = destAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation)
        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmUni.Instruction.withdrawAsset([
                originAsset
            ]),
            XcmUni.Instruction.buyExecution(
                XcmUni.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .one)
                )
            ),
            XcmUni.Instruction.depositReserveAsset(
                XcmUni.DepositReserveAssetValue(
                    assets: .wild(.singleCounted),
                    dest: destinationLocation,
                    xcm: [
                        XcmUni.Instruction.buyExecution(
                            XcmUni.BuyExecutionValue(
                                fees: half(asset: destAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmUni.Instruction.depositAsset(
                            XcmUni.DepositAssetValue(
                                assets: .wild(.singleCounted),
                                beneficiary: beneficiary
                            )
                        )
                    ]
                )
            )
        ]
    }

    func destinationReserveTransferProgram(
        for transferRequest: XcmUnweightedTransferRequest
    ) throws -> [XcmUni.Instruction] {
        let originAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.destination.parachainId)

        let assetLocation = try XcmUni.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let destAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmUni.Instruction.withdrawAsset([originAsset]),
            XcmUni.Instruction.buyExecution(
                XcmUni.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .one)
                )
            ),
            XcmUni.Instruction.initiateReserveWithdraw(
                XcmUni.InitiateReserveWithdrawValue(
                    assets: .wild(.singleCounted),
                    reserve: destAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmUni.Instruction.buyExecution(
                            XcmUni.BuyExecutionValue(
                                fees: half(asset: destAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmUni.Instruction.depositAsset(
                            XcmUni.DepositAssetValue(
                                assets: .wild(.singleCounted),
                                beneficiary: beneficiary
                            )
                        )
                    ]
                )
            )
        ]
    }

    func remoteReserveTransferProgram(
        for transferRequest: XcmUnweightedTransferRequest
    ) throws -> [XcmUni.Instruction] {
        let originAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.destination.parachainId)
        let reserveAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.reserve.parachainId)

        let assetLocation = try XcmUni.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let reserveAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: reserveAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let destAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmUni.Instruction.withdrawAsset([originAsset]),
            XcmUni.Instruction.buyExecution(
                XcmUni.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .one)
                )
            ),
            XcmUni.Instruction.initiateReserveWithdraw(
                XcmUni.InitiateReserveWithdrawValue(
                    assets: .wild(.singleCounted),
                    reserve: reserveAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmUni.Instruction.buyExecution(
                            XcmUni.BuyExecutionValue(
                                fees: half(asset: reserveAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmUni.Instruction.depositReserveAsset(
                            XcmUni.DepositReserveAssetValue(
                                assets: .wild(.singleCounted),
                                dest: destAbsoluteLocation.fromPointOfView(location: reserveAbsoluteLocation),
                                xcm: [
                                    XcmUni.Instruction.buyExecution(
                                        XcmUni.BuyExecutionValue(
                                            fees: half(asset: destAsset),
                                            weightLimit: .unlimited
                                        )
                                    ),
                                    XcmUni.Instruction.depositAsset(
                                        XcmUni.DepositAssetValue(
                                            assets: .wild(.singleCounted),
                                            beneficiary: beneficiary
                                        )
                                    )
                                ]
                            )
                        )
                    ]
                )
            )
        ]
    }

    func teleportTransferProgram(
        for transferRequest: XcmUnweightedTransferRequest
    ) throws -> [XcmUni.Instruction] {
        let originAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmUni.AbsoluteLocation(paraId: transferRequest.destination.parachainId)

        let assetLocation = try XcmUni.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let destAsset = XcmUni.Asset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation).toAssetId(),
            amount: transferRequest.amount
        )

        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmUni.Instruction.withdrawAsset([originAsset]),
            XcmUni.Instruction.buyExecution(
                // Here and onward: we use buy execution for the very first segment to be
                // able to pay delivery fees in sending asset
                // WeightLimit.one is used since it doesn't matter anyways as the message on origin is already weighted
                // The only restriction is that it cannot be zero or Unlimited
                XcmUni.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .one)
                )
            ),
            XcmUni.Instruction.initiateTeleport(
                XcmUni.InitiateTeleportValue(
                    assets: .wild(.singleCounted),
                    dest: destAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmUni.Instruction.buyExecution(
                            XcmUni.BuyExecutionValue(
                                fees: half(asset: destAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmUni.Instruction.depositAsset(
                            XcmUni.DepositAssetValue(
                                assets: .wild(.singleCounted),
                                beneficiary: beneficiary
                            )
                        )
                    ]
                )
            )
        ]
    }
}

extension XcmExecuteDerivator: XcmCallDerivating {
    func createTransferCallDerivationWrapper(
        for transferRequest: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        do {
            let transferType = transferRequest.deriveXcmTransferType()

            let program: XcmUni.Instructions = switch transferType {
            case .localReserve:
                try localReserveTransferProgram(for: transferRequest)
            case .destinationReserve:
                try destinationReserveTransferProgram(for: transferRequest)
            case .remoteReserve:
                try remoteReserveTransferProgram(for: transferRequest)
            case .teleport:
                try teleportTransferProgram(for: transferRequest)
            }

            let message = program.versioned(.V4)

            let originChainId = transferRequest.originChain.chainId
            let messageWeightWrapper = xcmPaymentFactory.queryMessageWeight(
                for: message,
                chainId: originChainId
            )

            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: originChainId)
            let palletNameWrapper = metadataFactory.createModuleNameResolutionWrapper(for: runtimeProvider)

            let mapOperation = ClosureOperation<RuntimeCallCollecting> {
                let palletName = try palletNameWrapper.targetOperation.extractNoCancellableResultData()
                let weightResult = try messageWeightWrapper.targetOperation.extractNoCancellableResultData()
                let weight = try weightResult.ensureOkOrError { XcmExecuteDerivatorError.messageWeightFailed($0) }

                let call = Xcm.ExecuteCall<Substrate.WeightV2>(
                    message: message,
                    maxWeight: weight
                )

                return RuntimeCallCollector(call: call.runtimeCall(for: palletName))
            }

            mapOperation.addDependency(messageWeightWrapper.targetOperation)
            mapOperation.addDependency(palletNameWrapper.targetOperation)

            return messageWeightWrapper
                .insertingHead(operations: palletNameWrapper.allOperations)
                .insertingTail(operation: mapOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
