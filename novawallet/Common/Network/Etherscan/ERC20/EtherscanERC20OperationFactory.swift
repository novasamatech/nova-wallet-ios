import Foundation
import Operation_iOS
import Foundation_iOS

final class EtherscanERC20OperationFactory: EtherscanBaseOperationFactory {
    let contractAddress: AccountAddress
    let chainFormat: ChainFormat

    init(
        contractAddress: AccountAddress,
        chainFormat: ChainFormat,
        baseUrl: URL,
        chainId: ChainModel.Id
    ) {
        self.contractAddress = contractAddress
        self.chainFormat = chainFormat

        super.init(
            baseUrl: baseUrl,
            chainId: chainId
        )
    }
}

// MARK: Private

private extension EtherscanERC20OperationFactory {
    func buildUrl(for info: EtherscanERC20HistoryInfo) -> URL? {
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

    func createInfo(
        accountId: AccountId,
        chainFormat: ChainFormat,
        pagination: EtherscanPagination
    ) throws -> EtherscanERC20HistoryInfo {
        let address = try accountId.toAddress(using: chainFormat)
        let ethereumAddress = address.toEthereumAddressWithChecksum() ?? address

        let info = EtherscanERC20HistoryInfo(
            address: ethereumAddress,
            contractaddress: contractAddress,
            page: pagination.page,
            offset: pagination.offset
        )

        return info
    }

    func createFetchWrapper(
        for accountId: AccountId,
        chainFormat: ChainFormat,
        pagination: EtherscanPagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard let info = try? createInfo(
            accountId: accountId,
            chainFormat: chainFormat,
            pagination: pagination
        ) else {
            return .createWithError(WalletRemoteHistoryError.fetchParamsCreation)
        }

        guard let url = buildUrl(for: info) else {
            return CompoundOperationWrapper.createWithError(NetworkBaseError.invalidUrl)
        }

        return createFetchWrapper(
            for: url,
            page: info.page,
            offset: info.offset,
            responseType: EtherscanERC20HistoryResponse.self
        )
    }
}

// MARK: WalletRemoteHistoryFactoryProtocol

extension EtherscanERC20OperationFactory: WalletRemoteHistoryFactoryProtocol {
    func isComplete(pagination: Pagination) -> Bool {
        let context = EtherscanHistoryContext(context: pagination.context ?? [:], defaultOffset: pagination.count)
        return context.isComplete
    }

    func createOperationWrapper(
        for accountId: AccountId,
        pagination: Pagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard let etherscanPagination = preparePagination(from: pagination) else {
            let historyData = prepareHistoryDataWhenFull(for: pagination)
            return CompoundOperationWrapper.createWithResult(historyData)
        }

        return createFetchWrapper(
            for: accountId,
            chainFormat: chainFormat,
            pagination: etherscanPagination
        )
    }
}
