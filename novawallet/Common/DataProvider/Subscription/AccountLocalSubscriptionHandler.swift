import Foundation

protocol AccountLocalSubscriptionHandler {
    func handleAccountResponse(
        result: Result<MetaChainAccountResponse?, Error>,
        accountId: AccountId,
        chain: ChainModel
    )
}

extension AccountLocalSubscriptionHandler {
    func handleAccountResponse(
        result _: Result<MetaChainAccountResponse?, Error>,
        accountId _: AccountId,
        chain _: ChainModel
    ) {}
}
