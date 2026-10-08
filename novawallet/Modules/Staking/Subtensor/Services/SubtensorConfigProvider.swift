import Foundation
import Operation_iOS

final class SubtensorConfigProvider: BaseFetchOperationFactory {
    let url: URL
    let novaFeeRateStore: SubtensorNovaFeeRateStore

    @Atomic(defaultValue: nil)
    private var config: SubtensorConfig?

    init(url: URL, novaFeeRateStore: SubtensorNovaFeeRateStore = .shared) {
        self.url = url
        self.novaFeeRateStore = novaFeeRateStore
    }
}

extension SubtensorConfigProvider: SubtensorSubnetLogosProviderProtocol {
    func createLogosWrapper() -> CompoundOperationWrapper<SubtensorSubnetLogos> {
        if let config {
            return CompoundOperationWrapper.createWithResult(config.subnetLogos)
        }

        let fetchOperation: BaseOperation<SubtensorConfig> = createFetchOperation(
            from: url,
            shouldUseCache: false,
            timeout: Constants.timeout
        )

        let cacheOperation = ClosureOperation<SubtensorSubnetLogos> {
            let config = try fetchOperation.extractNoCancellableResultData()
            self.config = config
            self.novaFeeRateStore.apply(config)
            return config.subnetLogos
        }

        cacheOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: cacheOperation, dependencies: [fetchOperation])
    }
}

private extension SubtensorConfigProvider {
    enum Constants {
        static let timeout: TimeInterval = 30
    }
}
