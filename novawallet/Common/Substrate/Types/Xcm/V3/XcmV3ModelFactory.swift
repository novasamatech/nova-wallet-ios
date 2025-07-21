import Foundation
import SubstrateSdk
import BigInt

final class XcmV3ModelFactory {
    func createMultilocation(
        origin: XcmTransferOrigin,
        destination: XcmTransferDestination
    ) -> XcmV3.Multilocation {
        XcmV3.AbsoluteLocation(
            paraId: destination.parachainId
        ).appendingAccountId(
            destination.accountId,
            isEthereumBase: destination.chain.isEthereumBased
        ).fromPointOfView(
            location: XcmV3.AbsoluteLocation(paraId: origin.parachainId)
        )
    }

    func createMultilocation(
        origin: XcmTransferOrigin,
        reserve: XcmTransferReserve
    ) -> XcmV3.Multilocation {
        XcmV3.AbsoluteLocation(
            paraId: reserve.parachainId
        ).fromPointOfView(
            location: XcmV3.AbsoluteLocation(
                paraId: origin.parachainId
            )
        )
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

            let model = XcmV3.GeneralKeyValue(
                length: generalKey.count,
                data: H256(partialData: generalKey)
            )

            junctions.append(.generalKey(model))
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
        origin: XcmTransferOrigin,
        destination: XcmTransferDestination
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, destination: destination)
        return .V3(multilocation)
    }

    func createVersionedMultilocation(
        origin: XcmTransferOrigin,
        reserve: XcmTransferReserve
    ) -> Xcm.VersionedMultilocation {
        let multilocation = createMultilocation(origin: origin, reserve: reserve)
        return .V3(multilocation)
    }

    func createVersionedMultiasset(
        origin: ChainModel,
        reserve: ChainModel,
        assetLocation: XcmAsset.ReservePath,
        amount: BigUInt
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

extension XcmV3ModelFactory: XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version _: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        let beneficiaryLocation = createVersionedMultilocation(
            origin: params.origin,
            destination: params.destination
        )

        let assetLocation = try createVersionedMultiasset(
            origin: params.origin.chainAsset.chain,
            reserve: params.reserve.chain,
            assetLocation: params.metadata.reserve.path,
            amount: params.amount
        )

        return XcmMultilocationAsset(beneficiary: beneficiaryLocation, asset: assetLocation)
    }
}
