import Foundation
import Operation_iOS

extension MetaAccountModel {
    func fetchChainAccountWrapper(
        for chainId: ChainModel.Id,
        using chainRegistry: ChainRegistryProtocol
    ) -> CompoundOperationWrapper<MetaChainAccountResponse> {
        let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: chainId)

        let selectedAccountOperation = ClosureOperation<MetaChainAccountResponse> {
            guard let chain = try chainWrapper.targetOperation.extractNoCancellableResultData() else {
                throw ChainRegistryError.noChain(chainId)
            }

            guard let selectedAccount = self.fetchMetaChainAccount(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            return selectedAccount
        }

        selectedAccountOperation.addDependency(chainWrapper.targetOperation)

        return chainWrapper.insertingTail(operation: selectedAccountOperation)
    }
}
