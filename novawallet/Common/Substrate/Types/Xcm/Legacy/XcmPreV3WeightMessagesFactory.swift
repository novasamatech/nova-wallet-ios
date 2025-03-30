import Foundation

final class XcmPreV3WeightMessagesFactory {
    let modelFactory = XcmPreV3ModelFactory()
}

private extension XcmPreV3WeightMessagesFactory {
    func createDestinationWeightMessage(
        from origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        feeParams: XcmTransferMetadata.LegacyFee,
        multiasset: Xcm.Multiasset
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
        multiasset: Xcm.Multiasset
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
        destination: Xcm.Multilocation,
        asset: Xcm.Multiasset
    ) throws -> Xcm.Message {
        let xcmInstructions: [Xcm.Instruction] = try instructions.map { rawInstruction in
            switch rawInstruction {
            case Xcm.Instruction.fieldWithdrawAsset:
                return .withdrawAsset([asset])
            case Xcm.Instruction.fieldClearOrigin:
                return .clearOrigin
            case Xcm.Instruction.fieldReserveAssetDeposited:
                return .reserveAssetDeposited([asset])
            case Xcm.Instruction.fieldBuyExecution:
                let value = Xcm.BuyExecutionValue(fees: asset, weightLimit: .unlimited)
                return .buyExecution(value)
            case Xcm.Instruction.fieldDepositAsset:
                let value = Xcm.DepositAssetValue(assets: .wild(.all), maxAssets: 1, beneficiary: destination)
                return .depositAsset(value)
            case Xcm.Instruction.fieldDepositReserveAsset:
                let value = Xcm.DepositReserveAssetValue(
                    assets: .wild(.all),
                    maxAssets: 1,
                    dest: destination,
                    xcm: []
                )

                return .depositReserveAsset(value)
            case Xcm.Instruction.fieldReceiveTeleportedAsset:
                return .receiveTeleportedAsset([asset])
            default:
                throw XcmWeightMessagesFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V2(xcmInstructions)
    }
}

extension XcmPreV3WeightMessagesFactory: XcmWeightMessagesFactoryProtocol {
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
