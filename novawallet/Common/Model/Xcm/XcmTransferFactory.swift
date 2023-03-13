import Foundation
import SubstrateSdk
import BigInt

protocol XcmTransferFactoryProtocol {
    func createVersionedMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation

    func createVersionedMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation

    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version: Xcm.Version?
    ) throws -> Xcm.VersionedMultiasset

    func createWeightMessage(
        from instructions: [String],
        destination: Xcm.Multilocation,
        asset: Xcm.Multiasset
    ) throws -> Xcm.Message
}

enum XcmTransferFactoryError: Error {
    case noOriginAssetFound(ChainAssetId)
    case noDestinationAssetFound(ChainAssetId)
    case noDestinationFound(ChainModel.Id)
    case noReserve(ChainAssetId)
    case unsupportedInstruction(String)
    case noInstructions(String)
    case noDestinationFee(origin: ChainAssetId, destination: ChainModel.Id)
    case noReserveFee(ChainAssetId)
    case noBaseWeight(ChainModel.Id)
}

extension XcmTransferFactoryProtocol {
    func createMultilocationAsset(
        from chainAsset: ChainAsset,
        reserve: ChainModel,
        destination: XcmTransferDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfers,
        version: XcmMultilocationAssetVersion
    ) throws -> XcmMultilocationAsset {
        let multilocation = createVersionedMultilocation(
            origin: chainAsset.chain,
            destination: destination,
            version: version.multiLocation
        )

        let originChainAssetId = chainAsset.chainAssetId

        guard xcmTransfers.transfer(
            from: originChainAssetId,
            destinationChainId: destination.chain.chainId
        ) != nil else {
            throw XcmTransferFactoryError.noDestinationAssetFound(originChainAssetId)
        }

        guard let reservePath = xcmTransfers.getReservePath(for: originChainAssetId) else {
            throw XcmTransferFactoryError.noReserve(originChainAssetId)
        }

        let multiasset = try createVersionedMultiasset(
            origin: chainAsset.chain,
            reserve: reserve,
            assetLocation: reservePath,
            amount: amount,
            version: version.multiAssets
        )

        return XcmMultilocationAsset(location: multilocation, asset: multiasset)
    }

    private func createDestinationWeightMessage(
        from chainAsset: ChainAsset,
        destination: XcmTransferDestination,
        xcmTransfer: XcmAssetTransfer,
        xcmTransfers: XcmTransfers,
        multiasset: Xcm.Multiasset
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

    private func createReserveWeightMessage(
        from chainAsset: ChainAsset,
        reserve: XcmTransferReserve,
        xcmTransfers: XcmTransfers,
        multiasset: Xcm.Multiasset
    ) throws -> Xcm.Message? {
        guard let reserveFee = xcmTransfers.reserveFee(from: chainAsset.chainAssetId) else {
            return nil
        }

        let reserveMultilocation) = createMultilocation(origin: chainAsset.chain, reserve: reserve)

        guard let reserveInstruction = xcmTransfers.instructions(for: reserveFee.instructions) else {
            throw XcmTransferFactoryError.noInstructions(reserveFee.instructions)
        }

        return try createWeightMessage(
            from: reserveInstruction,
            destination: reserveMultilocation,
            asset: multiasset
        )
    }

    func createWeightMessages(
        from chainAsset: ChainAsset,
        reserve: XcmTransferReserve,
        destination: XcmTransferDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfers
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

        let multiasset = try createMultiasset(
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

final class XcmTransferFactory {
    private func extractRelativeJunctions(from path: JSON) throws -> Xcm.Junctions {
        var junctions: [Xcm.Junction] = []

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

        return Xcm.Junctions(items: junctions)
    }

    private func extractAbsoluteJunctions(from path: JSON) throws -> Xcm.Junctions {
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

    private func createAssetMultilocation(
        from path: JSON,
        type: XcmAsset.LocationType,
        origin: ChainModel,
        reserve: ChainModel
    ) throws -> Xcm.Multilocation {
        let parents = extractParents(from: path, type: type, origin: origin, reserve: reserve)
        let junctions: Xcm.Junctions

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

        return Xcm.Multilocation(parents: parents, interior: junctions)
    }

    private func createMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination
    ) -> Xcm.Multilocation {
        let accountIdJunction: Xcm.Junction

        if destination.chain.isEthereumBased {
            let accountIdValue = Xcm.AccountId20Value(network: .any, key: destination.accountId)
            accountIdJunction = Xcm.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = Xcm.AccountId32Value(network: .any, accountId: destination.accountId)
            accountIdJunction = Xcm.Junction.accountId32(accountIdValue)
        }

        let parents: UInt8

        if !origin.isRelaychain, origin.chainId != destination.chain.chainId {
            parents = 1
        } else {
            parents = 0
        }

        let junctions: Xcm.Junctions

        if let parachainId = destination.parachainId {
            let networkJunction = Xcm.Junction.parachain(parachainId)
            junctions = Xcm.Junctions(items: [networkJunction, accountIdJunction])
        } else {
            junctions = Xcm.Junctions(items: [accountIdJunction])
        }

        return Xcm.Multilocation(parents: parents, interior: junctions)
    }

    func createMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve
    ) -> Xcm.Multilocation {
        let parents: UInt8

        if !origin.isRelaychain, origin.chainId != reserve.chain.chainId {
            parents = 1
        } else {
            parents = 0
        }

        let junctions: Xcm.Junctions

        if let parachainId = reserve.parachainId {
            let networkJunction = Xcm.Junction.parachain(parachainId)
            junctions = Xcm.Junctions(items: [networkJunction])
        } else {
            junctions = Xcm.Junctions(items: [])
        }

        return Xcm.Multilocation(parents: parents, interior: junctions)
    }

    func createMultiAsset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt
    ) throws -> Xcm.Multiasset {
        let multilocation = try createAssetMultilocation(
            from: assetLocation.path,
            type: assetLocation.type,
            origin: origin,
            reserve: reserve
        )

        return Xcm.Multiasset(multilocation: multilocation, amount: amount)
    }
}

extension XcmTransferFactory: XcmTransferFactoryProtocol {
    func createVersionedMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, destination: destination)
        return .versionedMultiLocation(for: version, multiLocation: multilocation)
    }

    func createVersionedMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, reserve: reserve)
        return .versionedMultiLocation(for: version, multiLocation: multilocation)
    }

    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version: Xcm.Version?
    ) throws -> Xcm.VersionedMultiasset {
        let multiasset = try createMultiAsset(
            origin: origin,
            reserve: reserve,
            assetLocation: assetLocation,
            amount: amount
        )

        return .versionedMultiasset(for: version, multiAsset: multiasset)
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
                let value = Xcm.BuyExecutionValue(fees: asset, weightLimit: .limited(weight: 0))
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
                throw XcmTransferFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V2(xcmInstructions)
    }
}
