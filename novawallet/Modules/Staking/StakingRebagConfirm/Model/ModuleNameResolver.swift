import RobinHood

protocol ModuleNameResolverProtocol {
    func resolveModuleName(possibleNames: [String]) -> CompoundOperationWrapper<String?>
}

final class ModuleNameResolver: ModuleNameResolverProtocol {
    let runtimeService: RuntimeProviderProtocol

    private var cachedResult: String?
    private var lastSearchPossibleNames: [String] = []

    init(runtimeService: RuntimeProviderProtocol) {
        self.runtimeService = runtimeService
    }

    func resolveModuleName(possibleNames: [String]) -> CompoundOperationWrapper<String?> {
        if let cachedResult = cachedResult, lastSearchPossibleNames == possibleNames {
            return CompoundOperationWrapper.createWithResult(cachedResult)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let resolveModuleNameOperation = ClosureOperation<String?> {
            let metadata = try codingFactoryOperation.extractNoCancellableResultData().metadata

            return BagList.possibleModuleNames.first { metadata.getModuleIndex($0) != nil }
        }

        resolveModuleNameOperation.addDependency(codingFactoryOperation)
        return CompoundOperationWrapper(
            targetOperation: resolveModuleNameOperation,
            dependencies: [codingFactoryOperation]
        )
    }
}
