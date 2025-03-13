import Foundation
import SubstrateSdk
import Operation_iOS

protocol DryRunOperationFactoryProtocol {
    func createDryRunCallWrapper<A>(
        _ call: RuntimeCall<A>,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<JSON>
}
