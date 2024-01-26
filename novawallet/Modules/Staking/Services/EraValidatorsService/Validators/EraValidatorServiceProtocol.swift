import Foundation
import RobinHood
import SubstrateSdk

protocol EraValidatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<EraStakersInfo>
}
