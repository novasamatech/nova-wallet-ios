import Foundation

final class XcmV3WeightMessagesFactory {
    let modelFactory = XcmV3ModelFactory()
}

private extension XcmV3WeightMessagesFactory {
    func createDestinationWeightMessage(
        from origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        feeParams: XcmTransferMetadata.LegacyFee,
        multiasset: XcmV3.Multiasset
    ) throws -> Xcm.Message {
        let multilocation = modelFactory.createMultilocation(origin: origin, destination: destination)

        return try createWeightMessage(
            from: feeParams.destinationExecution.instructions,
            destination: multilocation,
            asset: multiasset
        )
    }

    func createReserveWeightMessage(
        from origin: XcmTransferOrigin,
        reserve: XcmTransferReserve,
        feeParams: XcmTransferMetadata.LegacyFee,
        multiasset: XcmV3.Multiasset
    ) throws -> Xcm.Message? {
        guard let reserveInstructions = feeParams.reserveExecution?.instructions else {
            return nil
        }

        let reserveMultilocation = modelFactory.createMultilocation(origin: origin, reserve: reserve)

        return try createWeightMessage(
            from: reserveInstructions,
            destination: reserveMultilocation,
            asset: multiasset
        )
    }

    func createWeightMessage(
        from instructions: [String],
        destination: XcmV3.Multilocation,
        asset: XcmV3.Multiasset
    ) throws -> Xcm.Message {
        let xcmInstructions: [XcmV3.Instruction] = try instructions.map { rawInstruction in
            switch rawInstruction {
            case XcmV3.Instruction.fieldWithdrawAsset:
                return .withdrawAsset([asset])
            case XcmV3.Instruction.fieldClearOrigin:
                return .clearOrigin
            case XcmV3.Instruction.fieldReserveAssetDeposited:
                return .reserveAssetDeposited([asset])
            case XcmV3.Instruction.fieldBuyExecution:
                let value = XcmV3.BuyExecutionValue(fees: asset, weightLimit: .unlimited)
                return .buyExecution(value)
            case XcmV3.Instruction.fieldDepositAsset:
                let value = XcmV3.DepositAssetValue(assets: .wild(.all), beneficiary: destination)
                return .depositAsset(value)
            case XcmV3.Instruction.fieldDepositReserveAsset:
                let value = XcmV3.DepositReserveAssetValue(
                    assets: .wild(.all),
                    dest: destination,
                    xcm: []
                )

                return .depositReserveAsset(value)
            case XcmV3.Instruction.fieldReceiveTeleportedAsset:
                return .receiveTeleportedAsset([asset])
            default:
                throw XcmWeightMessagesFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V3(xcmInstructions)
    }
}

extension XcmV3WeightMessagesFactory: XcmWeightMessagesFactoryProtocol {
    func createWeightMessages(
        from params: XcmWeightMessagesParams,
        version _: Xcm.Version
    ) throws -> XcmWeightMessages {
        let multiasset = try modelFactory.createMultiAsset(
            origin: params.origin.chainAsset.chain,
            reserve: params.reserve.chain,
            assetLocation: params.reserveParams.path,
            amount: params.amount
        )

        let destinationMessage = try createDestinationWeightMessage(
            from: params.origin,
            destination: params.destination,
            feeParams: params.feeParams,
            multiasset: multiasset
        )

        let reserveMessage = try createReserveWeightMessage(
            from: params.origin,
            reserve: params.reserve,
            feeParams: params.feeParams,
            multiasset: multiasset
        )

        return XcmWeightMessages(destination: destinationMessage, reserve: reserveMessage)
    }
}
