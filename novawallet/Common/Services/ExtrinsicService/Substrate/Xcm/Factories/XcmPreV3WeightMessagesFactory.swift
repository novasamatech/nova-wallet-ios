import Foundation

final class XcmPreV3WeightMessagesFactory {
    let modelFactory = XcmPreV3ModelFactory()
}

private extension XcmPreV3WeightMessagesFactory {
    func createDestinationWeightMessage(
        from chainAsset: ChainAsset,
        destination: XcmTransferDestination,
        xcmTransfer: XcmAssetTransfer,
        xcmTransfers: XcmLegacyTransfers,
        multiasset: Xcm.Multiasset
    ) throws -> Xcm.Message {
        let multilocation = modelFactory.createMultilocation(origin: chainAsset.chain, destination: destination)

        let destinationInstructionsKey = xcmTransfer.destination.fee.instructions
        guard let destinationInstructions = xcmTransfers.instructions(for: destinationInstructionsKey) else {
            throw XcmModelError.noInstructions(destinationInstructionsKey)
        }

        return try createWeightMessage(
            from: destinationInstructions,
            destination: multilocation,
            asset: multiasset
        )
    }

    func createReserveWeightMessage(
        from chainAsset: ChainAsset,
        reserve: XcmTransferReserve,
        xcmTransfers: XcmLegacyTransfers,
        multiasset: Xcm.Multiasset
    ) throws -> Xcm.Message? {
        guard let reserveFee = xcmTransfers.reserveFee(from: chainAsset.chainAssetId) else {
            return nil
        }

        let reserveMultilocation = modelFactory.createMultilocation(origin: chainAsset.chain, reserve: reserve)

        guard let reserveInstruction = xcmTransfers.instructions(for: reserveFee.instructions) else {
            throw XcmModelError.noInstructions(reserveFee.instructions)
        }

        return try createWeightMessage(
            from: reserveInstruction,
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
        version _: Xcm.Version?
    ) throws -> XcmWeightMessages {
        let originChainAssetId = params.chainAsset.chainAssetId

        guard let xcmTransfer = params.xcmTransfers.transfer(
            from: originChainAssetId,
            destinationChainId: params.destination.chain.chainId
        ) else {
            throw XcmModelError.noDestinationAssetFound(originChainAssetId)
        }

        guard let reservePath = params.xcmTransfers.getReservePath(for: originChainAssetId) else {
            throw XcmModelError.noReserve(originChainAssetId)
        }

        let multiasset = try modelFactory.createMultiAsset(
            origin: params.chainAsset.chain,
            reserve: params.reserve.chain,
            assetLocation: reservePath,
            amount: params.amount
        )

        let destinationMessage = try createDestinationWeightMessage(
            from: params.chainAsset,
            destination: params.destination,
            xcmTransfer: xcmTransfer,
            xcmTransfers: params.xcmTransfers,
            multiasset: multiasset
        )

        let reserveMessage = try createReserveWeightMessage(
            from: params.chainAsset,
            reserve: params.reserve,
            xcmTransfers: params.xcmTransfers,
            multiasset: multiasset
        )

        return XcmWeightMessages(destination: destinationMessage, reserve: reserveMessage)
    }
}
