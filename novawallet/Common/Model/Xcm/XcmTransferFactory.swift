import Foundation
import SubstrateSdk
import BigInt

protocol XcmTransferFactoryProtocol {
    func createMultilocation(
        origin: ChainModel,
        destination: XcmAssetDestination
    ) -> Xcm.VersionedMultilocation

    func createMultilocation(
        origin: ChainModel,
        destination: XcmAssetReserve
    ) -> Xcm.VersionedMultilocation

    func createMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt
    ) throws -> Xcm.VersionedMultiasset

    func createWeightMessage(
        from instructions: [String],
        destination: Xcm.Multilocation,
        asset: Xcm.Multiasset
    ) throws -> Xcm.Message
}

enum XcmTransferFactoryError: Error {
    case noDestinationFound(ChainAssetId)
    case noReserve(ChainAssetId)
    case unsupportedInstruction(String)
    case noInstructions(String)
    case unsupportedMultiassetVersion
    case unsupportedMultilocationVersion
}

extension XcmTransferFactoryProtocol {
    func createMultilocationAsset(
        from chainAsset: ChainAsset,
        reserve: ChainModel,
        destination: XcmAssetDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfers
    ) throws -> XcmMultilocationAsset {
        let multilocation = createMultilocation(origin: chainAsset.chain, destination: destination)

        let originChainAssetId = chainAsset.chainAssetId

        guard xcmTransfers.transfer(
            from: originChainAssetId,
            destinationChainId: destination.chain.chainId
        ) != nil else {
            throw XcmTransferFactoryError.noDestinationFound(originChainAssetId)
        }

        guard let reservePath = xcmTransfers.getReservePath(for: originChainAssetId) else {
            throw XcmTransferFactoryError.noReserve(originChainAssetId)
        }

        let multiasset = try createMultiasset(
            origin: chainAsset.chain,
            reserve: reserve,
            assetLocation: reservePath,
            amount: amount
        )

        return XcmMultilocationAsset(location: multilocation, asset: multiasset)
    }

    func createWeightMessages(
        from chainAsset: ChainAsset,
        reserve: XcmAssetReserve,
        destination: XcmAssetDestination,
        amount: BigUInt,
        xcmTransfers: XcmTransfers
    ) throws -> XcmWeightMessages {
        guard case .V1(let multilocation) = createMultilocation(
            origin: chainAsset.chain,
            destination: destination
        ) else {
            throw XcmTransferFactoryError.unsupportedMultilocationVersion
        }

        let originChainAssetId = chainAsset.chainAssetId

        guard let xcmTransfer = xcmTransfers.transfer(
            from: originChainAssetId,
            destinationChainId: destination.chain.chainId
        ) else {
            throw XcmTransferFactoryError.noDestinationFound(originChainAssetId)
        }

        guard let reservePath = xcmTransfers.getReservePath(for: originChainAssetId) else {
            throw XcmTransferFactoryError.noReserve(originChainAssetId)
        }

        guard case .V1(let multiasset) = try createMultiasset(
            origin: chainAsset.chain,
            reserve: reserve.chain,
            assetLocation: reservePath,
            amount: amount
        ) else {
            throw XcmTransferFactoryError.unsupportedMultiassetVersion
        }

        let destinationInstructionsKey = xcmTransfer.destination.fee.instructions
        guard let destinationInstructions = xcmTransfers.instructions(for: destinationInstructionsKey) else {
            throw XcmTransferFactoryError.noInstructions(destinationInstructionsKey)
        }

        let destinationMessage = try createWeightMessage(
            from: destinationInstructions,
            destination: multilocation,
            asset: multiasset
        )

        let reserveMessage: Xcm.Message?

        if let reserveFee = xcmTransfer.reserveFee {
            guard case .V1(let reserveMultilocation) = createMultilocation(
                origin: chainAsset.chain,
                destination: reserve
            ) else {
                throw XcmTransferFactoryError.unsupportedMultilocationVersion
            }

            guard let reserveInstruction = xcmTransfers.instructions(for: reserveFee.instructions) else {
                throw XcmTransferFactoryError.noInstructions(reserveFee.instructions)
            }

            reserveMessage = try createWeightMessage(
                from: reserveInstruction,
                destination: reserveMultilocation,
                asset: multiasset
            )
        }

        return XcmWeightMessages(destination: destinationMessage, reserve: reserveMessage)
    }
}

final class XcmTransferFactory {
    private func extractRelativeJunctions(from path: JSON) throws -> Xcm.Junctions {
        var junctions: [Xcm.Junction] = []

        if let palletInstance = path.palletInstance?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = path.palletInstance?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)
            junctions.append(.generalKey(generalKey))
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
            return reserve.isRelaychain ? 0 : 1
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


}

extension XcmTransferFactory: XcmTransferFactoryProtocol {
    func createMultilocation(
        origin: ChainModel,
        destination: XcmAssetDestination
    ) -> Xcm.VersionedMultilocation {
        let accountIdJunction: Xcm.Junction

        if destination.chain.isEthereumBased {
            accountIdJunction = Xcm.Junction.accountKey20(.any, accountId: destination.accountId)
        } else {
            accountIdJunction = Xcm.Junction.accountId32(.any, accountId: destination.accountId)
        }

        let parents: UInt8

        if destination.parachainId != nil, origin.chainId != destination.chain.chainId {
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

        let multilocation = Xcm.Multilocation(parents: parents, interior: junctions)

        return .V1(multilocation)
    }

    func createMultilocation(
        origin: ChainModel,
        destination: XcmAssetReserve
    ) -> Xcm.VersionedMultilocation {
        let parents: UInt8

        if destination.parachainId != nil, origin.chainId != destination.chain.chainId {
            parents = 1
        } else {
            parents = 0
        }

        let junctions: Xcm.Junctions

        if let parachainId = destination.parachainId {
            let networkJunction = Xcm.Junction.parachain(parachainId)
            junctions = Xcm.Junctions(items: [networkJunction])
        } else {
            junctions = Xcm.Junctions(items: [])
        }

        let multilocation = Xcm.Multilocation(parents: parents, interior: junctions)

        return .V1(multilocation)
    }

    func createMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt
    ) throws -> Xcm.VersionedMultiasset {
        let multilocation = try createAssetMultilocation(
            from: assetLocation.path,
            type: assetLocation.type,
            origin: origin,
            reserve: reserve
        )

        let multiasset = Xcm.Multiasset.сoncreteFungible(location: multilocation, amount: amount)

        return .V1(multiasset)
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
                return .buyExecution(fees: asset, weightLimit: .limited(weight: 0))
            case Xcm.Instruction.fieldDepositAsset:
                return .depositAsset(.wild(.all), 1, destination)
            default:
                throw XcmTransferFactoryError.unsupportedInstruction(rawInstruction)
            }
        }

        return .V2(xcmInstructions)
    }
}
