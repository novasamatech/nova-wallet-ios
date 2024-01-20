import Foundation
import RobinHood

protocol EraNominationPoolsServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<NominationPools.ActivePools>
}
