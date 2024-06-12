import Foundation
import Operation_iOS
import SubstrateSdk

protocol EraValidatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<EraStakersInfo>
}
