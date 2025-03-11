import Foundation

final class XcmV3WeightMessagesFactory {
    let modelFactory = XcmV3ModelFactory()
}

private extension XcmV3WeightMessagesFactory {
    func createDestinationWeightMessage(
        from chainAsset: ChainAsset,
        destination: XcmTransferDestination,
        xcmTransfer: XcmAssetTransfer,
        xcmTransfers: XcmTransfers,
        multiasset: XcmV3.Multiasset
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
        xcmTransfers: XcmTransfers,
        multiasset: XcmV3.Multiasset
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
                throw XcmModelError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V3(xcmInstructions)
    }
}

extension XcmV3WeightMessagesFactory: XcmWeightMessagesFactoryProtocol {
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
