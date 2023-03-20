import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class EtherscanERC20OperationFactory: EtherscanBaseOperationFactory {
    let contractAddress: AccountAddress

    init(contractAddress: AccountAddress, baseUrl: URL, chainId: ChainModel.Id) {
        self.contractAddress = contractAddress

        super.init(baseUrl: baseUrl, chainId: chainId)
    }

    private func buildUrl(for info: EtherscanERC20HistoryInfo) -> URL? {
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "action", value: info.action),
            URLQueryItem(name: "address", value: info.address),
            URLQueryItem(name: "contractaddress", value: info.contractaddress),
            URLQueryItem(name: "module", value: info.module),
            URLQueryItem(name: "page", value: String(info.page)),
            URLQueryItem(name: "offset", value: String(info.offset)),
            URLQueryItem(name: "sort", value: info.sort),
            URLQueryItem(name: "apikey", value: EtherscanKeys.getApiKey(for: chainId))
        ]

        return components.url
    }

    func createFetchWrapper(
        for info: EtherscanERC20HistoryInfo
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard let url = buildUrl(for: info) else {
            return CompoundOperationWrapper.createWithError(NetworkBaseError.invalidUrl)
        }

        return createFetchWrapper(for: url, page: info.page, offset: info.offset)
    }
}

extension EtherscanERC20OperationFactory: WalletRemoteHistoryFactoryProtocol {
    func isComplete(pagination: Pagination) -> Bool {
        let context = EtherscanHistoryContext(context: pagination.context ?? [:], defaultOffset: pagination.count)
        return context.isComplete
    }

    func createOperationWrapper(
        for address: String,
        pagination: Pagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard let etherscanPagination = preparePagination(from: pagination) else {
            let historyData = prepareHistoryDataWhenFull(for: pagination)
            return CompoundOperationWrapper.createWithResult(historyData)
        }

        let info = EtherscanERC20HistoryInfo(
            address: address,
            contractaddress: contractAddress,
            page: etherscanPagination.page,
            offset: etherscanPagination.offset
        )

        return createFetchWrapper(for: info)
    }
}
