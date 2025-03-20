import Foundation
import BigInt

protocol XcmWeightMessagesFactoryProtocol {
    func createWeightMessages(
        from params: XcmWeightMessagesParams,
        version: Xcm.Version?
    ) throws -> XcmWeightMessages
}

struct XcmWeightMessagesParams {
    let chainAsset: ChainAsset
    let reserve: XcmTransferReserve
    let destination: XcmTransferDestination
    let amount: BigUInt
    let feeParams: XcmTransferMetadata.LegacyFee
    let reserveParams: XcmTransferMetadata.Reserve
}

enum XcmWeightMessagesFactoryError: Error {
    case unsupportedInstruction(String)
    case noInstructions(String)
    case unsupportedVersion(Xcm.Version?)
}

final class XcmWeightMessagesFactory {}

extension XcmWeightMessagesFactory: XcmWeightMessagesFactoryProtocol {
    func createWeightMessages(
        from params: XcmWeightMessagesParams,
        version: Xcm.Version?
    ) throws -> XcmWeightMessages {
        switch version {
        case nil, .V0, .V1, .V2:
            try XcmPreV3WeightMessagesFactory().createWeightMessages(
                from: params,
                version: version
            )
        case .V3:
            try XcmV3WeightMessagesFactory().createWeightMessages(
                from: params,
                version: version
            )
        case .V4:
            // TODO: Add support
            throw XcmWeightMessagesFactoryError.unsupportedVersion(version)
        }
    }
}
