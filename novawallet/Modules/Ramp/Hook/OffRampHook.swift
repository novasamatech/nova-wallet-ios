import Foundation
import Operation_iOS

typealias RampHookDelegate = OffRampHookDelegate & OnRampHookDelegate
typealias OffRampMessageHandling = RampMessageHandling

struct OffRampHookParams {
    let chainAsset: ChainAsset
    let refundAddress: AccountAddress
}

protocol OffRampHookDelegate: AnyObject {
    func didRequestTransfer(from model: OffRampTransferModel)
    func didFinishOperation()
}

protocol OffRampHookFactoryProtocol {
    func createHooks(
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate
    ) -> [RampHook]
}
