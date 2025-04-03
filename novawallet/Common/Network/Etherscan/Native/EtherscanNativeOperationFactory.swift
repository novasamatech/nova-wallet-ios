import Foundation
import Operation_iOS
import Foundation_iOS

final class EtherscanNativeOperationFactory: EtherscanBaseOperationFactory {
    let filter: WalletHistoryFilter
    let chainFormat: ChainFormat

    init(
        filter: WalletHistoryFilter,
        chainFormat: ChainFormat,
        baseUrl: URL,
        chainId: ChainModel.Id
    ) {
        self.filter = filter
        self.chainFormat = chainFormat

        super.init(
            baseUrl: baseUrl,
            chainId: chainId
        )
    }
}

// MARK: Private

private extension EtherscanNativeOperationFactory {
    func buildUrl(for info: EtherscanNativeHistoryInfo) -> URL? {
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

    func createInfo(
        accountId: AccountId,
        chainFormat: ChainFormat,
        pagination: EtherscanPagination
    ) throws -> EtherscanNativeHistoryInfo {
        let address = try accountId.toAddress(using: chainFormat)
        let ethereumAddress = address.toEthereumAddressWithChecksum() ?? address

        let info = EtherscanNativeHistoryInfo(
            address: ethereumAddress,
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
            responseType: EtherscanTxHistoryResponse.self
        )
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
                case .rewards, .poolRewards:
                    return filter.contains(.rewardsAndSlashes)
                case .swaps:
                    return filter.contains(.swaps)
                }
            }

            return .init(historyItems: filteredItems, context: data.context)
        }
    }
}

// MARK: WalletRemoteHistoryFactoryProtocol

extension EtherscanNativeOperationFactory: WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(
        for accountId: AccountId,
        pagination: Pagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard let etherscanPagination = preparePagination(from: pagination) else {
            let historyData = prepareHistoryDataWhenFull(for: pagination)
            return CompoundOperationWrapper.createWithResult(historyData)
        }

        let fetchWrapper = createFetchWrapper(
            for: accountId,
            chainFormat: chainFormat,
            pagination: etherscanPagination
        )

        let filterOperation = createFilterOperation(for: filter, dependingOn: fetchWrapper.targetOperation)

        filterOperation.addDependency(fetchWrapper.targetOperation)

        return .init(targetOperation: filterOperation, dependencies: fetchWrapper.allOperations)
    }

    func isComplete(pagination: Pagination) -> Bool {
        let context = EtherscanHistoryContext(context: pagination.context ?? [:], defaultOffset: pagination.count)
        return context.isComplete
    }
}
