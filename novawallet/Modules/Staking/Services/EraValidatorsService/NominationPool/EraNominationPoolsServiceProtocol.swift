import Foundation
import Operation_iOS

protocol EraNominationPoolsServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<NominationPools.ActivePools>
}
