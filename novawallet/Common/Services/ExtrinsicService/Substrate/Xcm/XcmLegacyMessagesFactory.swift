import Foundation
import BigInt

protocol XcmWeightMessagesFactoryProtocol {
    func createWeightMessages(
        from params: XcmWeightMessagesParams,
        version: Xcm.Version
    ) throws -> XcmWeightMessages
}

struct XcmWeightMessagesParams {
    let origin: XcmTransferOrigin
    let reserve: XcmTransferReserve
    let destination: XcmTransferDestination
    let amount: BigUInt
    let feeParams: XcmTransferMetadata.LegacyFee
    let reserveParams: XcmTransferMetadata.Reserve
}

enum XcmWeightMessagesFactoryError: Error {
    case unsupportedInstruction(String)
}

final class XcmLegacyMessagesFactory {
    let modelFactory = XcmLegacyModelFactory()
}

private extension XcmLegacyMessagesFactory {
    func createDestinationWeightMessage(
        from origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        feeParams: XcmTransferMetadata.LegacyFee,
        asset: XcmUni.Asset,
        version: Xcm.Version
    ) throws -> XcmUni.VersionedMessage {
        let location = modelFactory.createMultilocation(origin: origin, destination: destination)

        return try createWeightMessage(
            from: feeParams.destinationExecution.instructions,
            destination: location,
            asset: asset,
            version: version
        )
    }

    func createReserveWeightMessage(
        from origin: XcmTransferOrigin,
        reserve: XcmTransferReserve,
        feeParams: XcmTransferMetadata.LegacyFee,
        asset: XcmUni.Asset,
        version: Xcm.Version
    ) throws -> XcmUni.VersionedMessage? {
        guard let reserveInstructions = feeParams.reserveExecution?.instructions else {
            return nil
        }

        let reserveMultilocation = modelFactory.createMultilocation(origin: origin, reserve: reserve)

        return try createWeightMessage(
            from: reserveInstructions,
            destination: reserveMultilocation,
            asset: asset,
            version: version
        )
    }

    func createWeightMessage(
        from instructions: [String],
        destination: XcmUni.RelativeLocation,
        asset: XcmUni.Asset,
        version: Xcm.Version
    ) throws -> XcmUni.VersionedMessage {
        let xcmInstructions: XcmUni.Instructions = try instructions.map { rawInstruction in
            switch rawInstruction {
            case XcmUni.Instruction.fieldWithdrawAsset:
                return .withdrawAsset([asset])
            case XcmUni.Instruction.fieldClearOrigin:
                return .clearOrigin
            case XcmUni.Instruction.fieldReserveAssetDeposited:
                return .reserveAssetDeposited([asset])
            case XcmUni.Instruction.fieldBuyExecution:
                let value = XcmUni.BuyExecutionValue(fees: asset, weightLimit: .unlimited)
                return .buyExecution(value)
            case XcmUni.Instruction.fieldDepositAsset:
                let value = XcmUni.DepositAssetValue(assets: .wild(.all), beneficiary: destination)
                return .depositAsset(value)
            case XcmUni.Instruction.fieldDepositReserveAsset:
                let value = XcmUni.DepositReserveAssetValue(
                    assets: .wild(.all),
                    dest: destination,
                    xcm: []
                )

                return .depositReserveAsset(value)
            case XcmUni.Instruction.fieldReceiveTeleportedAsset:
                return .receiveTeleportedAsset([asset])
            default:
                throw XcmWeightMessagesFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .init(entity: xcmInstructions, version: version)
    }
}

extension XcmLegacyMessagesFactory: XcmWeightMessagesFactoryProtocol {
    func createWeightMessages(
        from params: XcmWeightMessagesParams,
        version: Xcm.Version
    ) throws -> XcmWeightMessages {
        let asset = try modelFactory.createMultiAsset(
            origin: params.origin.chainAsset.chain,
            reserve: params.reserve.chain,
            assetLocation: params.reserveParams.path,
            amount: params.amount
        )

        let destinationMessage = try createDestinationWeightMessage(
            from: params.origin,
            destination: params.destination,
            feeParams: params.feeParams,
            asset: asset,
            version: version
        )

        let reserveMessage = try createReserveWeightMessage(
            from: params.origin,
            reserve: params.reserve,
            feeParams: params.feeParams,
            asset: asset,
            version: version
        )

        return XcmWeightMessages(destination: destinationMessage, reserve: reserveMessage)
    }
}
