import Foundation
import Operation_iOS

protocol MercuryoCardParamsProviderProtocol {
    func fetchParamsOperation() -> BaseOperation<MercuryoCardParams>
}

final class MercuryoCardParamsProvider {
    let chainRegistry: ChainRegistryProtocol
    let wallet: MetaAccountModel
    let chainId: ChainModel.Id

    init(
        chainRegistry: ChainRegistryProtocol,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id
    ) {
        self.chainRegistry = chainRegistry
        self.wallet = wallet
        self.chainId = chainId
    }
}

// MARK: MercuryoCardParamsProviderProtocol

extension MercuryoCardParamsProvider: MercuryoCardParamsProviderProtocol {
    func fetchParamsOperation() -> BaseOperation<MercuryoCardParams> {
        let chainFetchWrapper = chainRegistry.asyncWaitChainWrapper(for: chainId)

        return ClosureOperation { [weak self] in
            guard
                let self,
                let chain = try chainFetchWrapper.targetOperation.extractNoCancellableResultData(),
                let utilityAsset = chain.utilityChainAsset()
            else {
                throw ChainModelFetchError.noAsset(assetId: 0)
            }

            guard
                let selectedAccount = wallet.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let refundAddress = try selectedAccount.accountId.toAddress(
                using: utilityAsset.chain.chainFormat
            )

            return MercuryoCardParams(
                chainAsset: utilityAsset,
                refundAddress: refundAddress
            )
        }
    }
}
