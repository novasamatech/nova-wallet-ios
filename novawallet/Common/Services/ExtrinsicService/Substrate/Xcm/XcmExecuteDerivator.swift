import Foundation
import Operation_iOS
import SubstrateSdk

enum XcmExecuteDerivatorError: Error {
    case messageWeightFailed(JSON)
}

final class XcmExecuteDerivator {
    enum TransferType {
        case teleport
        case localReserve
        case destinationReserve
        case remoteReserve(XcmV4.AbsoluteLocation)
    }

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
    func half(asset: XcmV4.Multiasset) -> XcmV4.Multiasset {
        switch asset.fun {
        case let .fungible(amount):
            XcmV4.Multiasset(assetId: asset.assetId, amount: amount / 2)
        case .nonFungible:
            asset
        }
    }

    func isTeleport(request: XcmUnweightedTransferRequest) -> Bool {
        request.origin.parachainId.isRelayOrSystemParachain &&
            request.destination.parachainId.isRelayOrSystemParachain &&
            request.origin.chainAsset.isUtilityAsset
    }

    func determineTransferType(
        for request: XcmUnweightedTransferRequest
    ) -> TransferType {
        if isTeleport(request: request) {
            .teleport
        } else if request.origin.chainAsset.chainAssetId.chainId == request.reserve.chain.chainId {
            .localReserve
        } else if request.destination.chain.chainId == request.reserve.chain.chainId {
            .destinationReserve
        } else {
            .remoteReserve(XcmV4.AbsoluteLocation(paraId: request.reserve.parachainId))
        }
    }

    func localReserveTransferProgram(
        for transferRequest: XcmUnweightedTransferRequest
    ) throws -> [XcmV4.Instruction] {
        let originAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.destination.parachainId)

        let assetLocation = try XcmV4.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation),
            amount: transferRequest.amount
        )

        let destAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation),
            amount: transferRequest.amount
        )

        let destinationLocation = destAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation)
        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmV4.Instruction.withdrawAsset([
                originAsset
            ]),
            XcmV4.Instruction.buyExecution(
                XcmV4.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .zero)
                )
            ),
            XcmV4.Instruction.depositReserveAsset(
                XcmV4.DepositReserveAssetValue(
                    assets: .wild(.allCounted(1)),
                    dest: destinationLocation,
                    xcm: [
                        XcmV4.Instruction.buyExecution(
                            XcmV4.BuyExecutionValue(
                                fees: half(asset: destAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmV4.Instruction.depositAsset(
                            XcmV4.DepositAssetValue(
                                assets: .wild(.allCounted(1)),
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
    ) throws -> [XcmV4.Instruction] {
        let originAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.destination.parachainId)

        let assetLocation = try XcmV4.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation),
            amount: transferRequest.amount
        )

        let destAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation),
            amount: transferRequest.amount
        )

        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmV4.Instruction.withdrawAsset([originAsset]),
            XcmV4.Instruction.buyExecution(
                XcmV4.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .zero)
                )
            ),
            XcmV4.Instruction.initiateReserveWithdraw(
                XcmV4.InitiateReserveWithdrawValue(
                    assets: .wild(.allCounted(1)),
                    reserve: destAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmV4.Instruction.buyExecution(
                            XcmV4.BuyExecutionValue(
                                fees: half(asset: destAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmV4.Instruction.depositAsset(
                            XcmV4.DepositAssetValue(
                                assets: .wild(.allCounted(1)),
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
    ) throws -> [XcmV4.Instruction] {
        let originAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.destination.parachainId)
        let reserveAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.reserve.parachainId)

        let assetLocation = try XcmV4.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation),
            amount: transferRequest.amount
        )

        let reserveAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: reserveAbsoluteLocation),
            amount: transferRequest.amount
        )

        let destAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation),
            amount: transferRequest.amount
        )

        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmV4.Instruction.withdrawAsset([originAsset]),
            XcmV4.Instruction.buyExecution(
                XcmV4.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .zero)
                )
            ),
            XcmV4.Instruction.initiateReserveWithdraw(
                XcmV4.InitiateReserveWithdrawValue(
                    assets: .wild(.allCounted(1)),
                    reserve: reserveAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmV4.Instruction.buyExecution(
                            XcmV4.BuyExecutionValue(
                                fees: half(asset: reserveAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmV4.Instruction.depositReserveAsset(
                            XcmV4.DepositReserveAssetValue(
                                assets: .wild(.allCounted(1)),
                                dest: destAbsoluteLocation.fromPointOfView(location: reserveAbsoluteLocation),
                                xcm: [
                                    XcmV4.Instruction.buyExecution(
                                        XcmV4.BuyExecutionValue(
                                            fees: half(asset: destAsset),
                                            weightLimit: .unlimited
                                        )
                                    ),
                                    XcmV4.Instruction.depositAsset(
                                        XcmV4.DepositAssetValue(
                                            assets: .wild(.allCounted(1)),
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
    ) throws -> [XcmV4.Instruction] {
        let originAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.destination.parachainId)

        let assetLocation = try XcmV4.AbsoluteLocation.createWithRawPath(
            transferRequest.metadata.reserve.path.path
        )

        let originAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: originAbsoluteLocation),
            amount: transferRequest.amount
        )

        let destAsset = XcmV4.Multiasset(
            assetId: assetLocation.fromPointOfView(location: destAbsoluteLocation),
            amount: transferRequest.amount
        )

        let beneficiary = destAbsoluteLocation.appendingAccountId(
            transferRequest.destination.accountId,
            isEthereumBase: transferRequest.destination.chain.isEthereumBased
        ).fromPointOfView(location: destAbsoluteLocation)

        return [
            XcmV4.Instruction.withdrawAsset([originAsset]),
            XcmV4.Instruction.buyExecution(
                XcmV4.BuyExecutionValue(
                    fees: half(asset: originAsset),
                    weightLimit: .limited(weight: .init(refTime: 0, proofSize: 0))
                )
            ),
            XcmV4.Instruction.initiateTeleport(
                XcmV4.InitiateTeleportValue(
                    assets: .wild(.all),
                    dest: destAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmV4.Instruction.buyExecution(
                            XcmV4.BuyExecutionValue(
                                fees: half(asset: destAsset),
                                weightLimit: .unlimited
                            )
                        ),
                        XcmV4.Instruction.depositAsset(
                            XcmV4.DepositAssetValue(
                                assets: .wild(.all),
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
            let transferType = determineTransferType(for: transferRequest)

            let program: [XcmV4.Instruction] = switch transferType {
            case .localReserve:
                try localReserveTransferProgram(for: transferRequest)
            case .destinationReserve:
                try destinationReserveTransferProgram(for: transferRequest)
            case .remoteReserve:
                try remoteReserveTransferProgram(for: transferRequest)
            case .teleport:
                try teleportTransferProgram(for: transferRequest)
            }

            let message = Xcm.Message.V4(program)

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

                let call = Xcm.ExecuteCall<BlockchainWeight.WeightV2>(
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
