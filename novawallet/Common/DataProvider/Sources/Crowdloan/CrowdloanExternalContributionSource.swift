import Foundation
import RobinHood

final class ExternalContributionDataProviderSource {
    let children: [ExternalContributionSourceProtocol]
    let accountId: AccountId
    let chain: ChainModel

    init(accountId: AccountId, chain: ChainModel, children: [ExternalContributionSourceProtocol]) {
        self.children = children
        self.accountId = accountId
        self.chain = chain
    }
}

extension ExternalContributionDataProviderSource: SingleValueProviderSourceProtocol {
    typealias Model = [ExternalContribution]

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let contributionOperations: [BaseOperation<[ExternalContribution]>] = children.map { source in
            source.getContributions(accountId: accountId, chain: chain)
        }

        guard !contributionOperations.isEmpty else {
            return CompoundOperationWrapper.createWithResult([])
        }

        let mergeOperation = ClosureOperation<[ExternalContribution]?> {
            contributionOperations.compactMap { operation in
                try? operation.extractNoCancellableResultData()
            }.flatMap { $0 }
        }

        contributionOperations.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: contributionOperations
        )
    }
}
