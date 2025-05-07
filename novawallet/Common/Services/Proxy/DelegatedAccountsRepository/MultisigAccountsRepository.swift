import Foundation
import SubstrateSdk
import Operation_iOS

protocol MultisigAccountsRepositoryProtocol {
    func fetchMultisigsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredMultisig]]>
}

final class MultisigAccountsRepository {
    private let chain: ChainModel

    private let mutex = NSLock()

    private var multisigsBySignatories: [AccountId: [DiscoveredMultisig]] = [:]

    init(chain: ChainModel) {
        self.chain = chain
    }
}

// MARK: MultisigAccountsRepositoryProtocol

extension MultisigAccountsRepository: MultisigAccountsRepositoryProtocol {
    func fetchMultisigsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredMultisig]]> {
        let cachedMultisigsForSignatories = accountIds
            .map { (signatory: $0, multisigs: multisigsBySignatories[$0]) }
            .reduce(into: [:]) { $0[$1.signatory] = $1.multisigs }

        let cachedSignatories = Set(cachedMultisigsForSignatories.keys)
        let nonCachedSignatories = accountIds.subtracting(cachedSignatories)

        guard !nonCachedSignatories.isEmpty else {
            return .createWithResult(cachedMultisigsForSignatories)
        }

        guard let apiURL = chain.externalApis?.getApis(for: .multisig)?.first?.url else {
            return .createWithResult([:])
        }

        let fetchFactory = SubqueryMultisigsOperationFactory(
            url: apiURL
        )

        let fetchWrapper = fetchFactory.createDiscoverMultisigsOperation(for: nonCachedSignatories)

        let mapOperation = ClosureOperation<[AccountId: [DiscoveredMultisig]]> { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let fetchResult = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            guard let fetchResult else { return [:] }

            let mappedFetchResult: [AccountId: [DiscoveredMultisig]] = fetchResult
                .reduce(into: [:]) { acc, multisig in
                    nonCachedSignatories.forEach { accountId in
                        guard multisig.signatories.contains(accountId) else {
                            return
                        }

                        if acc[accountId] == nil {
                            acc[accountId]?.append(multisig)
                        } else {
                            acc[accountId] = [multisig]
                        }
                    }
                }

            mutex.lock()
            multisigsBySignatories.merge(mappedFetchResult) { $0 + $1 }
            mutex.lock()

            let result = cachedMultisigsForSignatories.merging(mappedFetchResult) { $0 + $1 }
            return result
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }
}
