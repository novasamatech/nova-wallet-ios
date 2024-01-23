import Foundation
import RobinHood

protocol ParachainStakingCollatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<SelectedRoundCollators>
}
