import Foundation
import Operation_iOS

final class XcmExecuteDerivator {
    enum TransferType {
        case teleport
        case localReserve
        case destinationReserve
        case remoteReserve(XcmV4.AbsoluteLocation)
    }

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension XcmExecuteDerivator {
    func isTeleport(request: XcmUnweightedTransferRequest) -> Bool {
        request.origin.parachainId.isRelayOrSystemParachain &&
            request.destination.parachainId.isRelayOrSystemParachain &&
            request.origin.chainAsset.isUtilityAsset
    }

    func determineTransferType(
        for request: XcmUnweightedTransferRequest
    ) -> TransferType {
        if isTeleport(request: request) {
            return .teleport
        } else if request.origin.chainAsset.chainAssetId.chainId == request.reserve.chain.chainId {
            return .localReserve
        } else if request.destination.chain.chainId == request.reserve.chain.chainId {
            return .destinationReserve
        } else {
            return .remoteReserve(XcmV4.AbsoluteLocation(paraId: request.reserve.parachainId))
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
                    fees: originAsset,
                    weightLimit: .limited(weight: .init(refTime: 0, proofSize: 0))
                )
            ),
            XcmV4.Instruction.depositReserveAsset(
                XcmV4.DepositReserveAssetValue(
                    assets: XcmV4.AssetFilter.wild(.all),
                    dest: destinationLocation,
                    xcm: [
                        XcmV4.Instruction.buyExecution(
                            XcmV4.BuyExecutionValue(
                                fees: destAsset,
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
                    fees: originAsset,
                    weightLimit: .limited(weight: .init(refTime: 0, proofSize: 0))
                )
            ),
            XcmV4.Instruction.initiateReserveWithdraw(
                XcmV4.InitiateReserveWithdrawValue(
                    assets: .wild(.all),
                    reserve: destAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmV4.Instruction.buyExecution(
                            XcmV4.BuyExecutionValue(
                                fees: destAsset,
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

    func remoteReserveTransferProgram(
        for transferRequest: XcmUnweightedTransferRequest
    ) throws -> [XcmV4.Instruction] {
        let originAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.origin.parachainId)
        let destAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.destination.parachainId)
        let reserveAbsoluteLocation = XcmV4.AbsoluteLocation(paraId: transferRequest.destination.parachainId)

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
                    fees: originAsset,
                    weightLimit: .limited(weight: .init(refTime: 0, proofSize: 0))
                )
            ),
            XcmV4.Instruction.initiateReserveWithdraw(
                XcmV4.InitiateReserveWithdrawValue(
                    assets: .wild(.all),
                    reserve: reserveAbsoluteLocation.fromPointOfView(location: originAbsoluteLocation),
                    xcm: [
                        XcmV4.Instruction.buyExecution(
                            XcmV4.BuyExecutionValue(
                                fees: reserveAsset,
                                weightLimit: .unlimited
                            )
                        ),
                        XcmV4.Instruction.depositReserveAsset(
                            XcmV4.DepositReserveAssetValue(
                                assets: XcmV4.AssetFilter.wild(.all),
                                dest: destAbsoluteLocation.fromPointOfView(location: reserveAbsoluteLocation),
                                xcm: [
                                    XcmV4.Instruction.buyExecution(
                                        XcmV4.BuyExecutionValue(
                                            fees: destAsset,
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
                    fees: originAsset,
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
                                fees: destAsset,
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

            let call = Xcm.ExecuteCall<BlockchainWeight.WeightV2>(
                message: message,
                maxWeight: .init(refTime: 0, proofSize: 0)
            )

            let collector = RuntimeCallCollector(
                call: call.runtimeCall(for: "PalletXcm")
            )

            return .createWithResult(collector)
        } catch {
            return .createWithError(error)
        }
    }
}
