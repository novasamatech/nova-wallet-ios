import Foundation

protocol GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    )

    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )
}

extension GeneralLocalStorageHandler {
    func handleBlockNumber(
        result _: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {}

    func handleAccountInfo(
        result _: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}
}
