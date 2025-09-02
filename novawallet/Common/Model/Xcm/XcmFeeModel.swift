import Foundation
import BigInt

protocol XcmFeeModelProtocol {
    var senderPart: BigUInt { get }
    var holdingPart: BigUInt { get }
}

struct XcmFeeModel: XcmFeeModelProtocol {
    // fee paid in native token in the origin chain
    let senderPart: BigUInt

    // total fee paid in sending token in reserve and destination chains
    let holdingPart: BigUInt
}

extension XcmFeeModel {
    static func combine(_ fee1: XcmFeeModelProtocol, _ fee2: XcmFeeModelProtocol) -> XcmFeeModel {
        .init(
            senderPart: fee1.senderPart + fee2.senderPart,
            holdingPart: fee1.holdingPart + fee2.holdingPart
        )
    }

    static func zero() -> XcmFeeModel {
        .init(senderPart: 0, holdingPart: 0)
    }
}
