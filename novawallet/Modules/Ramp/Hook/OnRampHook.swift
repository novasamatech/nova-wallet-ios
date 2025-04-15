import Foundation

protocol OnRampHookDelegate: AnyObject {
    func didFinishOperation()
}

protocol OnRampHookFactoryProtocol {
    func createHooks(for delegate: OnRampHookDelegate) -> [RampHook]
}
