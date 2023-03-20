import Foundation
import RobinHood
import CommonWallet
import SoraFoundation

final class EtherscanNativeOperationFactory: EtherscanBaseOperationFactory {
    let filter: WalletHistoryFilter

    init(filter: WalletHistoryFilter, baseUrl: URL, chainId: ChainModel.Id) {
        self.filter = filter

        super.init(baseUrl: baseUrl, chainId: chainId)
    }

    private func buildUrl(for info: EtherscanNativeHistoryInfo) -> URL? {
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "action", value: info.action),
            URLQueryItem(name: "address", value: info.address),
            URLQueryItem(name: "module", value: info.module),
            URLQueryItem(name: "page", value: String(info.page)),
            URLQueryItem(name: "offset", value: String(info.offset)),
            URLQueryItem(name: "sort", value: info.sort),
            URLQueryItem(name: "apikey", value: EtherscanKeys.getApiKey(for: chainId))
        ]

        return components.url
    }

    func createFetchWrapper(
        for info: EtherscanNativeHistoryInfo
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard let url = buildUrl(for: info) else {
            return CompoundOperationWrapper.createWithError(NetworkBaseError.invalidUrl)
        }

        return createFetchWrapper(for: url, page: info.page, offset: info.offset)
    }

    func createFilterOperation(
        for filter: WalletHistoryFilter,
        dependingOn dataOperation: BaseOperation<WalletRemoteHistoryData>
    ) -> BaseOperation<WalletRemoteHistoryData> {
        ClosureOperation<WalletRemoteHistoryData> {
            let data = try dataOperation.extractNoCancellableResultData()

            guard filter != .all else {
                return data
            }

            let filteredItems = data.historyItems.filter { item in
                switch item.label {
                case .transfers:
                    return filter.contains(.transfers)
                case .extrinsics:
                    return filter.contains(.extrinsics)
                case .rewards:
                    return filter.contains(.rewardsAndSlashes)
                }
            }

            return .init(historyItems: filteredItems, context: data.context)
        }
    }
}

extension EtherscanNativeOperationFactory: WalletRemoteHistoryFactoryProtocol {
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

        let info = EtherscanNativeHistoryInfo(
            address: address,
            page: etherscanPagination.page,
            offset: etherscanPagination.offset
        )

        let fetchWrapper = createFetchWrapper(for: info)

        let filterOperation = createFilterOperation(for: filter, dependingOn: fetchWrapper.targetOperation)

        filterOperation.addDependency(fetchWrapper.targetOperation)

        return .init(targetOperation: filterOperation, dependencies: fetchWrapper.allOperations)
    }
}
