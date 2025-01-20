import Foundation
import Operation_iOS

protocol MythosCollatorServiceProtocol: ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<MythosSessionCollators>
}
