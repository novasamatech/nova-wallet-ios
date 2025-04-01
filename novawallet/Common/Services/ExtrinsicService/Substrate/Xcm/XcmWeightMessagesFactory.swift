import Foundation
import BigInt

protocol XcmWeightMessagesFactoryProtocol {
    func createWeightMessages(
        from params: XcmWeightMessagesParams,
        version: Xcm.Version
    ) throws -> XcmWeightMessages
}

struct XcmWeightMessagesParams {
    let origin: XcmTransferOrigin
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
        version: Xcm.Version
    ) throws -> XcmWeightMessages {
        switch version {
        case .V0, .V1, .V2:
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
            try XcmV4WeightMessagesFactory().createWeightMessages(
                from: params,
                version: version
            )
        case .V5:
            try XcmV5WeightMessagesFactory().createWeightMessages(
                from: params,
                version: version
            )
        }
    }
}
