import Foundation
import SubstrateSdk
import BigInt

protocol XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset
}

struct XcmMultilocationAssetParams {
    let origin: ChainAsset
    let reserve: ChainModel
    let destination: XcmTransferDestination
    let amount: BigUInt
    let metadata: XcmTransferMetadata
}

enum XcmModelFactoryError: Error {
    case unsupported(Xcm.Version?)
}

final class XcmModelFactory {}

extension XcmModelFactory: XcmModelFactoryProtocol {
    func createMultilocationAsset(
        for params: XcmMultilocationAssetParams,
        version: Xcm.Version
    ) throws -> XcmMultilocationAsset {
        switch version {
        case .V0, .V1, .V2:
            try XcmPreV3ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        case .V3:
            try XcmV3ModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        case .V4:
            // TODO: Implement
            throw XcmModelFactoryError.unsupported(version)
        }
    }
}
