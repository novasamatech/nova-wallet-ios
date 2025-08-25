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
    let origin: XcmTransferOrigin
    let reserve: XcmTransferReserve
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
        switch params.metadata.fee {
        case .dynamic:
            try XcmDynamicModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        case .legacy:
            try XcmLegacyModelFactory().createMultilocationAsset(
                for: params,
                version: version
            )
        }
    }
}
