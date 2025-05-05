import Foundation

final class XcmV5WeightMessagesFactory {
    let modelFactory = XcmV5ModelFactory()
}

private extension XcmV5WeightMessagesFactory {
    func createDestinationWeightMessage(
        from origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        feeParams: XcmTransferMetadata.LegacyFee,
        multiasset: XcmV5.Multiasset
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
        multiasset: XcmV5.Multiasset
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
        destination: XcmV5.Multilocation,
        asset: XcmV5.Multiasset
    ) throws -> Xcm.Message {
        let xcmInstructions: [XcmV5.Instruction] = try instructions.map { rawInstruction in
            switch rawInstruction {
            case XcmV5.Instruction.fieldWithdrawAsset:
                return .withdrawAsset([asset])
            case XcmV5.Instruction.fieldClearOrigin:
                return .clearOrigin
            case XcmV5.Instruction.fieldReserveAssetDeposited:
                return .reserveAssetDeposited([asset])
            case XcmV5.Instruction.fieldBuyExecution:
                let value = XcmV5.BuyExecutionValue(fees: asset, weightLimit: .unlimited)
                return .buyExecution(value)
            case XcmV5.Instruction.fieldDepositAsset:
                let value = XcmV5.DepositAssetValue(assets: .wild(.all), beneficiary: destination)
                return .depositAsset(value)
            case XcmV5.Instruction.fieldDepositReserveAsset:
                let value = XcmV5.DepositReserveAssetValue(
                    assets: .wild(.all),
                    dest: destination,
                    xcm: []
                )

                return .depositReserveAsset(value)
            case XcmV5.Instruction.fieldReceiveTeleportedAsset:
                return .receiveTeleportedAsset([asset])
            default:
                throw XcmWeightMessagesFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V5(xcmInstructions)
    }
}

extension XcmV5WeightMessagesFactory: XcmWeightMessagesFactoryProtocol {
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
