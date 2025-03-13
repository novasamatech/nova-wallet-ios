import Foundation
import SubstrateSdk
import BigInt

final class XcmV3ModelFactory {
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
}

private extension XcmV3ModelFactory {
    func extractRelativeJunctions(from path: JSON) throws -> XcmV3.Junctions {
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

    func extractAbsoluteJunctions(from path: JSON) throws -> XcmV3.Junctions {
        let commonJunctions = try extractRelativeJunctions(from: path)

        if let parachainId = path.parachainId?.unsignedIntValue {
            return commonJunctions.prepending(components: [.parachain(ParaId(parachainId))])
        } else {
            return commonJunctions
        }
    }

    func extractParents(
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

    func createVersionedMultilocation(
        origin: ChainModel,
        destination: XcmTransferDestination
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, destination: destination)
        return .V3(multilocation)
    }

    func createVersionedMultilocation(
        origin: ChainModel,
        reserve: XcmTransferReserve
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, reserve: reserve)
        return .V3(multilocation)
    }
}

extension XcmV3ModelFactory: XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: XcmMultilocationAssetVersion
    ) throws -> XcmMultilocationAsset {
        let originChainAsset = params.origin

        let multilocation = createVersionedMultilocation(
            origin: originChainAsset.chain,
            destination: params.destination
        )

        let originChainAssetId = originChainAsset.chainAssetId

        guard params.xcmTransfers.getAssetTransfer(
            from: originChainAssetId,
            destinationChainId: params.destination.chain.chainId
        ) != nil else {
            throw XcmModelError.noDestinationAssetFound(originChainAssetId)
        }

        guard let reservePath = params.xcmTransfers.getAssetReservePath(for: originChainAsset) else {
            throw XcmModelError.noReserve(originChainAssetId)
        }

        let multiasset = try createVersionedMultiasset(
            origin: originChainAsset.chain,
            reserve: params.reserve,
            assetLocation: reservePath,
            amount: params.amount,
            version: version.multiAssets
        )

        return XcmMultilocationAsset(location: multilocation, asset: multiasset)
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
}
