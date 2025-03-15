import Foundation
import Operation_iOS

class EtherscanBaseOperationFactory {
    let baseUrl: URL
    let chainId: ChainModel.Id

    init(
        baseUrl: URL,
        chainId: ChainModel.Id
    ) {
        self.baseUrl = baseUrl
        self.chainId = chainId
    }

    func createFetchWrapper<R: EtherscanWalletHistoryDecodable>(
        for url: URL,
        page: Int,
        offset: Int,
        responseType: R.Type
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(UserAgent.nova, forHTTPHeaderField: "User-Agent")

            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<WalletRemoteHistoryData> { data in
            let items = try JSONDecoder().decode(responseType, from: data).historyItems

            let isComplete = items.count < offset
            let context = EtherscanHistoryContext(
                page: page,
                isComplete: isComplete,
                defaultOffset: offset
            )

            let historyData = WalletRemoteHistoryData(historyItems: items, context: context.toContext())

            return historyData
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func preparePagination(from pagination: Pagination) -> EtherscanPagination? {
        let context = EtherscanHistoryContext(context: pagination.context ?? [:], defaultOffset: pagination.count)

        guard !context.isComplete else {
            return nil
        }

        if let currentPage = context.page {
            return .init(page: currentPage + 1, offset: context.defaultOffset)
        } else {
            // for etherscan paging starts from 1
            return .init(page: 1, offset: context.defaultOffset)
        }
    }

    func prepareHistoryDataWhenFull(for pagination: Pagination) -> WalletRemoteHistoryData {
        let context = EtherscanHistoryContext(context: pagination.context ?? [:], defaultOffset: pagination.count)
        return WalletRemoteHistoryData(historyItems: [], context: context.toContext())
    }
}
