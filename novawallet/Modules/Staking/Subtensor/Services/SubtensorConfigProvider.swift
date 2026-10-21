import Foundation
import Operation_iOS

final class SubtensorConfigProvider: BaseFetchOperationFactory {
    let url: URL

    @Atomic(defaultValue: nil)
    private var config: SubtensorConfig?

    init(url: URL) {
        self.url = url
    }
}

extension SubtensorConfigProvider: SubtensorConfigProviding {
    func createLogosWrapper() -> CompoundOperationWrapper<SubtensorSubnetLogos> {
        createConfigWrapper().mapped { $0.subnetLogos }
    }

    func createNovaFeeRateWrapper() -> CompoundOperationWrapper<BigRational> {
        let configWrapper = createConfigWrapper()

        let rateOperation = ClosureOperation<BigRational> {
            do {
                let config = try configWrapper.targetOperation.extractNoCancellableResultData()
                return config.novaFeeRate ?? SubtensorNovaFeeConstants.fallbackRate
            } catch {
                throw SubtensorOperationError.novaFeeUnavailable
            }
        }

        rateOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: rateOperation)
    }
}

private extension SubtensorConfigProvider {
    enum Constants {
        static let timeout: TimeInterval = 30
    }

    func createConfigWrapper() -> CompoundOperationWrapper<SubtensorConfig> {
        if let config {
            return CompoundOperationWrapper.createWithResult(config)
        }

        let fetchOperation: BaseOperation<SubtensorConfig> = createFetchOperation(
            from: url,
            shouldUseCache: false,
            timeout: Constants.timeout
        )

        return CompoundOperationWrapper(targetOperation: fetchOperation).mapped { config in
            self.config = config
            return config
        }
    }
}
