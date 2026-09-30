import Foundation
import Operation_iOS

final class SubtensorSubnetLogosProvider: BaseFetchOperationFactory {
    let url: URL

    @Atomic(defaultValue: nil)
    private var logos: SubtensorSubnetLogos?

    init(url: URL) {
        self.url = url
    }
}

extension SubtensorSubnetLogosProvider: SubtensorSubnetLogosProviderProtocol {
    func createLogosWrapper() -> CompoundOperationWrapper<SubtensorSubnetLogos> {
        if let logos {
            return CompoundOperationWrapper.createWithResult(logos)
        }

        let fetchOperation: BaseOperation<SubtensorSubnetLogos> = createFetchOperation(
            from: url,
            shouldUseCache: false,
            timeout: Constants.timeout
        )

        let cacheOperation = ClosureOperation<SubtensorSubnetLogos> {
            let logos = try fetchOperation.extractNoCancellableResultData()
            self.logos = logos
            return logos
        }

        cacheOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: cacheOperation, dependencies: [fetchOperation])
    }
}

private extension SubtensorSubnetLogosProvider {
    enum Constants {
        static let timeout: TimeInterval = 30
    }
}
