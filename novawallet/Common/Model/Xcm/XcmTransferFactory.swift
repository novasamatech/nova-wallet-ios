import Foundation
import SubstrateSdk
import BigInt

protocol XcmTransferFactoryProtocol {
    func createMultilocation(
        origin: ChainModel,
        destination: ChainModel,
        destinationParachainId: ParaId?,
        beneficiary: AccountId
    ) -> Xcm.VersionedMultilocation

    func createMultiasset(
        assetLocationPath: JSON,
        assetLocationType: XcmAsset.LocationType,
        origin: ChainModel,
        reserve: ChainModel,
        amount: BigUInt
    ) throws -> Xcm.VersionedMultiasset
}

final class XcmTransferFactory: XcmTransferFactoryProtocol {
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

    func createMultilocation(
        origin: ChainModel,
        destination: ChainModel,
        destinationParachainId: ParaId?,
        beneficiary: AccountId
    ) -> Xcm.VersionedMultilocation {
        let accountIdJunction: Xcm.Junction

        if destination.isEthereumBased {
            accountIdJunction = Xcm.Junction.accountKey20(.any, accountId: beneficiary)
        } else {
            accountIdJunction = Xcm.Junction.accountId32(.any, accountId: beneficiary)
        }

        let parents: UInt8

        if destinationParachainId != nil, origin.chainId != destination.chainId {
            parents = 1
        } else {
            parents = 0
        }

        let junctions: Xcm.Junctions

        if let parachainId = destinationParachainId {
            let networkJunction = Xcm.Junction.parachain(parachainId)
            junctions = Xcm.Junctions(items: [networkJunction, accountIdJunction])
        } else {
            junctions = Xcm.Junctions(items: [accountIdJunction])
        }

        let multilocation = Xcm.Multilocation(parents: parents, interior: junctions)

        return .V1(multilocation)
    }

    func createMultiasset(
        assetLocationPath: JSON,
        assetLocationType: XcmAsset.LocationType,
        origin: ChainModel,
        reserve: ChainModel,
        amount: BigUInt
    ) throws -> Xcm.VersionedMultiasset {
        let multilocation = try createAssetMultilocation(
            from: assetLocationPath,
            type: assetLocationType,
            origin: origin,
            reserve: reserve
        )

        let multiasset = Xcm.Multiasset.сoncreteFungible(location: multilocation, amount: amount)

        return .V1(multiasset)
    }
}
