import Foundation
import Operation_iOS
import SDKLogger
import NovaOperationSupport

struct AnalyticsGateway {
    let uploadFactory: AnalyticsUploadOperationFactoryProtocol
}

protocol AnalyticsGatewayResolving: AnyObject {
    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway>
}

final class AnalyticsGatewayResolver: AnalyticsGatewayResolving {
    private let authSource: AnalyticsAuthProvidingProtocol
    private let logger: SDKLoggerProtocol

    init(authSource: AnalyticsAuthProvidingProtocol, logger: SDKLoggerProtocol) {
        self.authSource = authSource
        self.logger = logger
    }

    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway> {
        let authWrapper = authSource.createAuthWrapper()
        let mapOperation = ClosureOperation<AnalyticsGateway> { [logger] in
            let auth = try authWrapper.targetOperation.extractNoCancellableResultData()
            return AnalyticsGateway(uploadFactory: AnalyticsUploadOperationFactory(auth: auth, logger: logger))
        }
        mapOperation.addDependency(authWrapper.targetOperation)
        return authWrapper.insertingTail(operation: mapOperation)
    }
}
