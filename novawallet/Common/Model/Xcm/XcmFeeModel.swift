import Foundation
import BigInt

protocol XcmFeeModelProtocol {
    var senderPart: BigUInt { get }
    var holdingPart: BigUInt { get }
    var weightLimit: BigUInt { get }
}

struct XcmFeeModel: XcmFeeModelProtocol {
    // fee paid in native token in the origin chain
    let senderPart: BigUInt

    // total fee paid in sending token in reserve and destination chains
    let holdingPart: BigUInt

    // limit of the xcm
    let weightLimit: BigUInt
}

extension XcmFeeModel {
    static func combine(_ fee1: XcmFeeModelProtocol, _ fee2: XcmFeeModelProtocol) -> XcmFeeModel {
        .init(
            senderPart: fee1.senderPart + fee2.senderPart,
            holdingPart: fee1.holdingPart + fee2.holdingPart,
            weightLimit: max(fee1.weightLimit, fee2.weightLimit)
        )
    }

    static func zero() -> XcmFeeModel {
        .init(senderPart: 0, holdingPart: 0, weightLimit: 0)
    }
}
