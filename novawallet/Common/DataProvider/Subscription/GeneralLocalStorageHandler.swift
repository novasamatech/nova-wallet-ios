import Foundation

protocol GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    )
}

extension GeneralLocalStorageHandler {
    func handleBlockNumber(
        result _: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {}
}
