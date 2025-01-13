import Foundation
import SubstrateSdk
import Operation_iOS

protocol DryRunOperationFactoryProtocol {
    func createDryRunCallWrapper<A>(_ call: RuntimeCall<A>) -> CompoundOperationWrapper<JSON>
    func createDryRunXcmMessage(_ message: Xcm.Message) -> CompoundOperationWrapper<JSON>
}
