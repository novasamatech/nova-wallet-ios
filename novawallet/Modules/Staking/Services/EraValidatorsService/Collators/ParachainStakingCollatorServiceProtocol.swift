import Foundation
import Operation_iOS

protocol ParachainStakingCollatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<SelectedRoundCollators>
}
