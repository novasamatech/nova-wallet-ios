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
        origin: XcmTransferOrigin,
        destination: XcmTransferDestination
    ) -> Xcm.Multilocation {
        Xcm.AbsoluteLocation(
            paraId: destination.parachainId
        ).appendingAccountId(
            destination.accountId,
            isEthereumBase: destination.chain.isEthereumBased
        ).fromPointOfView(
            location: Xcm.AbsoluteLocation(paraId: origin.parachainId)
        )
    }

    func createMultilocation(
        origin: XcmTransferOrigin,
        reserve: XcmTransferReserve
    ) -> Xcm.Multilocation {
        Xcm.AbsoluteLocation(
            paraId: reserve.parachainId
        ).fromPointOfView(
            location: Xcm.AbsoluteLocation(
                paraId: origin.parachainId
            )
        )
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
        origin: XcmTransferOrigin,
        destination: XcmTransferDestination,
        version: Xcm.Version?
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, destination: destination)
        return .versionedMultiLocation(for: version, multiLocation: multilocation)
    }

    func createVersionedMultilocation(
        origin: XcmTransferOrigin,
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
        version: Xcm.Version
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

extension XcmPreV3ModelFactory: XcmModelFactoryProtocol {
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
