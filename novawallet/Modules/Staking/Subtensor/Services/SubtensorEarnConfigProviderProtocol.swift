import Foundation
import Operation_iOS

protocol SubtensorEarnConfigProviderProtocol: AnyObject {
    func createConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig>

    func createBackgroundConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig>
}
