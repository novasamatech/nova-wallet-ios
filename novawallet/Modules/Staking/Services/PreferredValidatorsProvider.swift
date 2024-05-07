import Foundation
import RobinHood

protocol PreferredValidatorsProviding {
    func createPreferredValidatorsWrapper(for chain: ChainModel) -> CompoundOperationWrapper<[AccountId]>
}

final class PreferredValidatorsProvider: BaseFetchOperationFactory {
    typealias Store = [ChainModel.Id: [AccountAddress]]

    @Atomic(defaultValue: nil)
    private var allValidators: Store?

    let remoteUrl: URL
    let timeout: TimeInterval

    init(remoteUrl: URL, timeout: TimeInterval = 30) {
        self.remoteUrl = remoteUrl
        self.timeout = timeout
    }

    private func convert(addresses: [AccountAddress], chainFormat: ChainFormat) throws -> [AccountId] {
        try addresses.compactMap { try $0.toAccountId(using: chainFormat) }
    }
}

extension PreferredValidatorsProvider: PreferredValidatorsProviding {
    func createPreferredValidatorsWrapper(for chain: ChainModel) -> CompoundOperationWrapper<[AccountId]> {
        if
            let validators = allValidators?[chain.chainId],
            let accountIds = try? convert(addresses: validators, chainFormat: chain.chainFormat) {
            return CompoundOperationWrapper.createWithResult(accountIds)
        }

        let fetchOperation: BaseOperation<Store> = createFetchOperation(
            from: remoteUrl,
            shouldUseCache: false,
            timeout: timeout
        )

        let mapOperation = ClosureOperation<[AccountId]> {
            guard let newStore = try? fetchOperation.extractNoCancellableResultData() else {
                return []
            }

            self.allValidators = newStore

            return (try? self.convert(addresses: newStore[chain.chainId] ?? [], chainFormat: chain.chainFormat)) ?? []
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
