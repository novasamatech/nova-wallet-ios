import Foundation
import SubstrateSdk
import Operation_iOS

final class MultisigAccountsRepository {
    private let chain: ChainModel

    @Atomic(defaultValue: [:])
    private var multisigsBySignatories: [AccountId: [DiscoveredMultisig]]

    init(chain: ChainModel) {
        self.chain = chain
    }
}

// MARK: DelegatedAccountsRepositoryProtocol

extension MultisigAccountsRepository: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for signatoryIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
        let cachedMultisigsForSignatories = signatoryIds
            .reduce(into: [:]) { $0[$1] = multisigsBySignatories[$1] }

        let cachedSignatories = Set(cachedMultisigsForSignatories.keys)
        let nonCachedSignatories = signatoryIds.subtracting(cachedSignatories)

        guard !nonCachedSignatories.isEmpty else {
            return .createWithResult(cachedMultisigsForSignatories)
        }

        guard let apiURL = chain.externalApis?.getApis(for: .multisig)?.first?.url else {
            return .createWithResult([:])
        }

        let fetchFactory = SubqueryMultisigsOperationFactory(
            url: apiURL
        )

        let fetchOperation = fetchFactory.createDiscoverMultisigsOperation(for: nonCachedSignatories)

        let mapOperation = ClosureOperation<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
            let fetchResult = try fetchOperation.extractNoCancellableResultData()

            guard let fetchResult else { return [:] }

            let mappedFetchResult: [AccountId: [DiscoveredMultisig]] = fetchResult
                .reduce(into: [:]) { acc, multisig in
                    nonCachedSignatories.forEach { accountId in
                        guard multisig.signatories.contains(accountId) else {
                            return
                        }

                        if acc[accountId] == nil {
                            acc[accountId] = [multisig]
                        } else {
                            acc[accountId]?.append(multisig)
                        }
                    }
                }

            self.multisigsBySignatories.merge(mappedFetchResult) { $0 + $1 }

            let result = cachedMultisigsForSignatories
                .merging(mappedFetchResult) { $0 + $1 }

            return result
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }
}
