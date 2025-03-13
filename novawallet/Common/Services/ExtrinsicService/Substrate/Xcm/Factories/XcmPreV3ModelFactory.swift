import Foundation
import SubstrateSdk
import BigInt

final class XcmPreV3ModelFactory {
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

    func createMultilocation(
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

        let junctions: Xcm.JunctionsV2

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

        let junctions: Xcm.JunctionsV2

        if let parachainId = reserve.parachainId {
            let networkJunction = Xcm.Junction.parachain(parachainId)
            junctions = Xcm.JunctionsV2(items: [networkJunction])
        } else {
            junctions = Xcm.JunctionsV2(items: [])
        }

        return Xcm.Multilocation(parents: parents, interior: junctions)
    }
}

private extension XcmPreV3ModelFactory {
    func extractRelativeJunctions(from path: JSON) throws -> Xcm.JunctionsV2 {
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

    func extractAbsoluteJunctions(from path: JSON) throws -> Xcm.JunctionsV2 {
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
    ) throws -> Xcm.Multilocation {
        let parents = extractParents(from: path, type: type, origin: origin, reserve: reserve)
        let junctions: Xcm.JunctionsV2

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
}

extension XcmPreV3ModelFactory: XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: XcmMultilocationAssetVersion
    ) throws -> XcmMultilocationAsset {
        let originChainAsset = params.origin

        let multilocation = createVersionedMultilocation(
            origin: originChainAsset.chain,
            destination: params.destination,
            version: version.multiLocation
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
}
