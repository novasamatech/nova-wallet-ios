import Foundation
import Operation_iOS

public protocol AnalyticsInfraURLProviding {
    func createInfraURLWrapper() -> CompoundOperationWrapper<URL>
}
