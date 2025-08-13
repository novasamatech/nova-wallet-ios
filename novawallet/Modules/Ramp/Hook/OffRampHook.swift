import Foundation
import Operation_iOS

typealias RampHook = PayCardHook
typealias RampHookDelegate = OffRampHookDelegate & OnRampHookDelegate
typealias OffRampHookParams = MercuryoCardParams
typealias OffRampMessageHandling = PayCardMessageHandling
typealias OffRampTransferModel = PayCardTopupModel

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
