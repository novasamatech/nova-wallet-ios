import Foundation

protocol GiftReclaimWalletCheckerProtocol {
    func findGiftRecipientAccount(
        for chain: ChainModel,
        in wallet: MetaAccountModel
    ) throws -> AccountId
}

final class GiftReclaimWalletChecker: GiftReclaimWalletCheckerProtocol {
    func findGiftRecipientAccount(
        for chain: ChainModel,
        in wallet: MetaAccountModel
    ) throws -> AccountId {
        let request = chain.accountRequest()
        let accountResponse = wallet.fetch(for: request)

        guard let accountResponse else {
            throw GiftReclaimWalletCheckError.noAccountForChain(
                chainId: chain.chainId,
                name: chain.name
            )
        }

        return accountResponse.accountId
    }
}

enum GiftReclaimWalletCheckError: Error {
    case noAccountForChain(chainId: ChainModel.Id, name: String)
}
