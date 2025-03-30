import Foundation

final class XcmV4WeightMessagesFactory {
    let modelFactory = XcmV4ModelFactory()
}

private extension XcmV4WeightMessagesFactory {
    func createDestinationWeightMessage(
        from origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        feeParams: XcmTransferMetadata.LegacyFee,
        multiasset: XcmV4.Multiasset
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
        multiasset: XcmV4.Multiasset
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
        destination: XcmV4.Multilocation,
        asset: XcmV4.Multiasset
    ) throws -> Xcm.Message {
        let xcmInstructions: [XcmV4.Instruction] = try instructions.map { rawInstruction in
            switch rawInstruction {
            case XcmV4.Instruction.fieldWithdrawAsset:
                return .withdrawAsset([asset])
            case XcmV4.Instruction.fieldClearOrigin:
                return .clearOrigin
            case XcmV4.Instruction.fieldReserveAssetDeposited:
                return .reserveAssetDeposited([asset])
            case XcmV4.Instruction.fieldBuyExecution:
                let value = XcmV4.BuyExecutionValue(fees: asset, weightLimit: .unlimited)
                return .buyExecution(value)
            case XcmV4.Instruction.fieldDepositAsset:
                let value = XcmV4.DepositAssetValue(assets: .wild(.all), beneficiary: destination)
                return .depositAsset(value)
            case XcmV4.Instruction.fieldDepositReserveAsset:
                let value = XcmV4.DepositReserveAssetValue(
                    assets: .wild(.all),
                    dest: destination,
                    xcm: []
                )

                return .depositReserveAsset(value)
            case XcmV4.Instruction.fieldReceiveTeleportedAsset:
                return .receiveTeleportedAsset([asset])
            default:
                throw XcmWeightMessagesFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V4(xcmInstructions)
    }
}

extension XcmV4WeightMessagesFactory: XcmWeightMessagesFactoryProtocol {
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
