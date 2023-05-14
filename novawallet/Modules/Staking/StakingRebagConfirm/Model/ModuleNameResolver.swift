import RobinHood

protocol ModuleNameResolverProtocol {
    func resolveModuleName(possibleNames: [String]) -> CompoundOperationWrapper<String?>
}

final class ModuleNameResolver: ModuleNameResolverProtocol {
    let runtimeService: RuntimeProviderProtocol

    init(runtimeService: RuntimeProviderProtocol) {
        self.runtimeService = runtimeService
    }

    func resolveModuleName(possibleNames _: [String]) -> CompoundOperationWrapper<String?> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let resolveModuleNameOperation = ClosureOperation<String?> { [weak self] in
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
