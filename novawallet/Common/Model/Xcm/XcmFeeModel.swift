import Foundation
import BigInt

protocol XcmFeeModelProtocol {
    var senderPart: BigUInt { get }
    var holdingPart: BigUInt { get }
    var weightLimit: BigUInt { get }
}

extension XcmFeeModelProtocol {
    var total: BigUInt {
        senderPart + holdingPart
    }
}

struct XcmFeeModel: XcmFeeModelProtocol {
    let senderPart: BigUInt
    let holdingPart: BigUInt
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
