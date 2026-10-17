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

        return CompoundOperationWrapper(targetOperation: fetchOperation).mapped { config in
            self.config = config
            self.novaFeeRateStore.apply(config)
            return config.subnetLogos
        }
    }
}

private extension SubtensorConfigProvider {
    enum Constants {
        static let timeout: TimeInterval = 30
    }
}
