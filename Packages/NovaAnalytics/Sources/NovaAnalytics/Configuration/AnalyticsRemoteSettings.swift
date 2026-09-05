import Foundation
import Operation_iOS

public protocol AnalyticsRemoteSettings {
    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool>
}
