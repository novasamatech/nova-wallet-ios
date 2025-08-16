import Foundation
import SubstrateSdk
import BigInt

final class XcmLegacyModelFactory {
    func createMultiAsset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt
    ) throws -> XcmUni.Asset {
        let location = try createAssetMultilocation(
            from: assetLocation.path,
            type: assetLocation.type,
            origin: origin,
            reserve: reserve
        )

        return XcmUni.Asset(location: location, amount: amount)
    }

    func createMultilocation(
        origin: XcmTransferOrigin,
        destination: XcmTransferDestination
    ) -> XcmUni.RelativeLocation {
        XcmUni.AbsoluteLocation(
            paraId: destination.parachainId
        ).appendingAccountId(
            destination.accountId,
            isEthereumBase: destination.chain.isEthereumBased
        ).fromPointOfView(
            location: XcmUni.AbsoluteLocation(paraId: origin.parachainId)
        )
    }

    func createMultilocation(
        origin: XcmTransferOrigin,
        reserve: XcmTransferReserve
    ) -> XcmUni.RelativeLocation {
        XcmUni.AbsoluteLocation(
            paraId: reserve.parachainId
        ).fromPointOfView(
            location: XcmUni.AbsoluteLocation(
                paraId: origin.parachainId
            )
        )
    }
}

private extension XcmLegacyModelFactory {
    func extractRelativeJunctions(from path: JSON) throws -> XcmUni.Junctions {
        var junctions: [XcmUni.Junction] = []

        if let palletInstance = path.palletInstance?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = path.generalKey?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)

            let model = XcmUni.GeneralKeyValue(data: generalKey)

            junctions.append(.generalKey(model))
        } else if let generalIndexString = path.generalIndex?.stringValue {
            guard let generalIndex = BigUInt(generalIndexString) else {
                throw CommonError.dataCorruption
            }

            junctions.append(.generalIndex(generalIndex))
        }

        return XcmUni.Junctions(items: junctions)
    }

    func extractAbsoluteJunctions(from path: JSON) throws -> XcmUni.Junctions {
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
    ) throws -> XcmUni.RelativeLocation {
        let parents = extractParents(from: path, type: type, origin: origin, reserve: reserve)
        let junctions: XcmUni.Junctions

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

        return XcmUni.RelativeLocation(parents: parents, interior: junctions)
    }

    func createVersionedMultilocation(
        origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        version: Xcm.Version
    ) -> XcmUni.VersionedLocation {
        let location = createMultilocation(origin: origin, destination: destination)
        return .init(entity: location, version: version)
    }

    func createVersionedMultilocation(
        origin: XcmTransferOrigin,
        reserve: XcmTransferReserve,
        version: Xcm.Version
    ) -> XcmUni.VersionedLocation {
        let location = createMultilocation(origin: origin, reserve: reserve)
        return .init(entity: location, version: version)
    }

    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt,
        version: Xcm.Version
    ) throws -> XcmUni.VersionedAsset {
        let asset = try createMultiAsset(
            origin: origin,
            reserve: reserve,
            assetLocation: assetLocation,
            amount: amount
        )

        return .init(entity: asset, version: version)
    }
}

extension XcmLegacyModelFactory: XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        let benificiaryLocation = createVersionedMultilocation(
            origin: params.origin,
            destination: params.destination,
            version: version
        )

        let assetLocation = try createVersionedMultiasset(
            origin: params.origin.chainAsset.chain,
            reserve: params.reserve.chain,
            assetLocation: params.metadata.reserve.path,
            amount: params.amount,
            version: version
        )

        return XcmMultilocationAsset(beneficiary: benificiaryLocation, asset: assetLocation)
    }
}
