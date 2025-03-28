import Foundation
import SubstrateSdk
import BigInt

final class XcmV3TransferFactory {
    private func extractRelativeJunctions(from path: JSON) throws -> XcmV3.Junctions {
        var junctions: [XcmV3.Junction] = []

        if let palletInstance = path.palletInstance?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = path.generalKey?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)
            junctions.append(.generalKey(generalKey))
        } else if let generalIndexString = path.generalIndex?.stringValue {
            guard let generalIndex = BigUInt(generalIndexString) else {
                throw CommonError.dataCorruption
            }

            junctions.append(.generalIndex(generalIndex))
        }

        return XcmV3.Junctions(items: junctions)
    }

    private func extractAbsoluteJunctions(from path: JSON) throws -> XcmV3.Junctions {
        let commonJunctions = try extractRelativeJunctions(from: path)

        if let parachainId = path.parachainId?.unsignedIntValue {
            return commonJunctions.prepending(components: [.parachain(ParaId(parachainId))])
        } else {
            return commonJunctions
        }
    }

    private func extractParents(
        from path: JSON,
        type: XcmAsset.LocationType,
        origin: ChainModel,
        reserve: ChainModel
    ) -> UInt8 {
        switch type {
        case .absolute:
            return origin.isRelaychain ? 0 : 1
        case .relative:
            if origin.chainId != reserve.chainId, !origin.isRelaychain {
                return 1
            } else {
                return 0
            }
        case .concrete:
            let parents = path.parents?.unsignedIntValue ?? 0
            return UInt8(parents)
        }
    }

    func createAssetMultilocation(
        from path: JSON,
        type: XcmAsset.LocationType,
        origin: ChainModel,
        reserve: ChainModel
    ) throws -> XcmV3.Multilocation {
        let parents = extractParents(from: path, type: type, origin: origin, reserve: reserve)
        let junctions: XcmV3.Junctions

        switch type {
        case .absolute, .concrete:
            junctions = try extractAbsoluteJunctions(from: path)
        case .relative:
            if origin.chainId == reserve.chainId {
                junctions = try extractRelativeJunctions(from: path)
            } else {
                junctions = try extractAbsoluteJunctions(from: path)
            }
        }

        return XcmV3.Multilocation(parents: parents, interior: junctions)
    }

    func createMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination
    ) -> XcmV3.Multilocation {
        let accountIdJunction: XcmV3.Junction

        if destination.chain.isEthereumBased {
            let accountIdValue = XcmV3.AccountId20Value(network: nil, key: destination.accountId)
            accountIdJunction = XcmV3.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = XcmV3.AccountId32Value(network: nil, accountId: destination.accountId)
            accountIdJunction = XcmV3.Junction.accountId32(accountIdValue)
        }

        let parents: UInt8

        if !origin.isRelaychain, origin.chainId != destination.chain.chainId {
            parents = 1
        } else {
            parents = 0
        }

        let junctions: XcmV3.Junctions

        if let parachainId = destination.parachainId {
            let networkJunction = XcmV3.Junction.parachain(parachainId)
            junctions = XcmV3.Junctions(items: [networkJunction, accountIdJunction])
        } else {
            junctions = XcmV3.Junctions(items: [accountIdJunction])
        }

        return XcmV3.Multilocation(parents: parents, interior: junctions)
    }

    func createMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve
    ) -> XcmV3.Multilocation {
        let parents: UInt8

        if !origin.isRelaychain, origin.chainId != reserve.chain.chainId {
            parents = 1
        } else {
            parents = 0
        }

        let junctions: XcmV3.Junctions

        if let parachainId = reserve.parachainId {
            let networkJunction = XcmV3.Junction.parachain(parachainId)
            junctions = XcmV3.Junctions(items: [networkJunction])
        } else {
            junctions = XcmV3.Junctions(items: [])
        }

        return XcmV3.Multilocation(parents: parents, interior: junctions)
    }

    func createMultiAsset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt
    ) throws -> XcmV3.Multiasset {
        let multilocation = try createAssetMultilocation(
            from: assetLocation.path,
            type: assetLocation.type,
            origin: origin,
            reserve: reserve
        )

        return XcmV3.Multiasset(multilocation: multilocation, amount: amount)
    }

    func createDestinationWeightMessage(
        from chainAsset: ChainAsset,
        destination: XcmTransferDestination,
        xcmTransfer: XcmAssetTransfer,
        xcmTransfers: XcmTransfers,
        multiasset: XcmV3.Multiasset
    ) throws -> Xcm.Message {
        let multilocation = createMultilocation(origin: chainAsset.chain, destination: destination)

        let destinationInstructionsKey = xcmTransfer.destination.fee.instructions
        guard let destinationInstructions = xcmTransfers.instructions(for: destinationInstructionsKey) else {
            throw XcmTransferFactoryError.noInstructions(destinationInstructionsKey)
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

        let reserveMultilocation = createMultilocation(origin: chainAsset.chain, reserve: reserve)

        guard let reserveInstruction = xcmTransfers.instructions(for: reserveFee.instructions) else {
            throw XcmTransferFactoryError.noInstructions(reserveFee.instructions)
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
                throw XcmTransferFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V3(xcmInstructions)
    }
}

extension XcmV3TransferFactory: XcmTransferFactoryProtocol {
    func createVersionedMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination,
        version _: Xcm.Version?
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, destination: destination)
        return .V3(multilocation)
    }

    func createVersionedMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve,
        version _: Xcm.Version?
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, reserve: reserve)
        return .V3(multilocation)
    }

    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version _: Xcm.Version?
    ) throws -> Xcm.VersionedMultiasset {
        let multiasset = try createMultiAsset(
            origin: origin,
            reserve: reserve,
            assetLocation: assetLocation,
            amount: amount
        )

        return .V3(multiasset)
    }

    func createWeightMessages(
        from chainAsset: ChainAsset,
        reserve: XcmTransferReserve,
        destination: XcmTransferDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfers,
        version _: Xcm.Version?
    ) throws -> XcmWeightMessages {
        let originChainAssetId = chainAsset.chainAssetId

        guard let xcmTransfer = xcmTransfers.transfer(
            from: originChainAssetId,
            destinationChainId: destination.chain.chainId
        ) else {
            throw XcmTransferFactoryError.noDestinationAssetFound(originChainAssetId)
        }

        guard let reservePath = xcmTransfers.getReservePath(for: originChainAssetId) else {
            throw XcmTransferFactoryError.noReserve(originChainAssetId)
        }

        let multiasset = try createMultiAsset(
            origin: chainAsset.chain,
            reserve: reserve.chain,
            assetLocation: reservePath,
            amount: amount
        )

        let destinationMessage = try createDestinationWeightMessage(
            from: chainAsset,
            destination: destination,
            xcmTransfer: xcmTransfer,
            xcmTransfers: xcmTransfers,
            multiasset: multiasset
        )

        let reserveMessage = try createReserveWeightMessage(
            from: chainAsset,
            reserve: reserve,
            xcmTransfers: xcmTransfers,
            multiasset: multiasset
        )

        return XcmWeightMessages(destination: destinationMessage, reserve: reserveMessage)
    }
}
