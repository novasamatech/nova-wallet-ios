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

    init(chain: ChainModel) {
        self.chain = chain
    }
}

// MARK: MultisigAccountsRepositoryProtocol

extension MultisigAccountsRepository: MultisigAccountsRepositoryProtocol {
    func fetchMultisigsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredMultisig]]> {
        guard let apiURL = chain.externalApis?.getApis(for: .multisig)?.first?.url else {
            return .createWithResult([:])
        }

        let fetchFactory = SubqueryMultisigsOperationFactory(
            url: apiURL
        )

        let fetchWrapper = fetchFactory.createDiscoverMultisigsOperation(for: accountIds)

        let mapOperation = ClosureOperation<[AccountId: [DiscoveredMultisig]]> {
            let fetchResult = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            guard let fetchResult else { return [:] }

            return fetchResult.reduce(into: [:]) { acc, multisig in
                let signatories = Set(multisig.signatories)
                let knownAccountIds = accountIds.intersection(signatories)

                knownAccountIds.forEach { accountId in
                    if acc[accountId] == nil {
                        acc[accountId]?.append(multisig)
                    } else {
                        acc[accountId] = [multisig]
                    }
                }
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mapOperation)
    }
}
