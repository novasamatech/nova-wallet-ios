import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class EtherscanOperationFactory {
    let contractAddress: AccountAddress
    let url: URL

    init(contractAddress: AccountAddress, url: URL) {
        self.contractAddress = contractAddress
        self.url = url
    }

    private func buildUrl(for info: EtherscanHistoryInfo) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "action", value: info.action),
            URLQueryItem(name: "address", value: info.address),
            URLQueryItem(name: "contractaddress", value: info.contractaddress),
            URLQueryItem(name: "module", value: info.module),
            URLQueryItem(name: "page", value: String(info.page)),
            URLQueryItem(name: "offset", value: String(info.offset)),
            URLQueryItem(name: "sort", value: info.sort)
        ]

        return components.url
    }

    func createFetchWrapper(for info: EtherscanHistoryInfo) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard let url = buildUrl(for: info) else {
            return CompoundOperationWrapper.createWithError(NetworkBaseError.invalidUrl)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(UserAgent.nova, forHTTPHeaderField: "User-Agent")

            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<WalletRemoteHistoryData> { data in
            let items = try JSONDecoder().decode(EtherscanResponse.self, from: data).result

            let isComplete = items.count < info.offset
            let context = EtherscanHistoryContext(
                page: info.page,
                isComplete: isComplete,
                defaultOffset: info.offset
            )

            let historyData = WalletRemoteHistoryData(historyItems: items, context: context.toContext())

            return historyData
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

extension EtherscanOperationFactory: WalletRemoteHistoryFactoryProtocol {
    func isComplete(pagination: Pagination) -> Bool {
        let context = EtherscanHistoryContext(context: pagination.context ?? [:], defaultOffset: pagination.count)
        return context.isComplete
    }

    func createOperationWrapper(
        for address: String,
        pagination: Pagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let context = EtherscanHistoryContext(context: pagination.context ?? [:], defaultOffset: pagination.count)

        guard !context.isComplete else {
            let historyData = WalletRemoteHistoryData(historyItems: [], context: context.toContext())
            return CompoundOperationWrapper.createWithResult(historyData)
        }

        let page: Int

        if let currentPage = context.page {
            page = currentPage + 1
        } else {
            page = 0
        }

        let info = EtherscanHistoryInfo(
            address: address,
            contractaddress: contractAddress,
            page: page,
            offset: context.defaultOffset
        )

        return createFetchWrapper(for: info)
    }
}
