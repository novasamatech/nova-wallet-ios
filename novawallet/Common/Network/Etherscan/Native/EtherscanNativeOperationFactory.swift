import Foundation
import Operation_iOS
import SoraFoundation

final class EtherscanNativeOperationFactory: EtherscanBaseOperationFactory {
    let filter: WalletHistoryFilter

    init(
        filter: WalletHistoryFilter,
        baseUrl: URL,
        chainId: ChainModel.Id,
        operationManager: OperationManagerProtocol
    ) {
        self.filter = filter

        super.init(
            baseUrl: baseUrl,
            chainId: chainId,
            operationManager: operationManager
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

    func createInfoOperation(
        accountId: AccountId,
        chainFormat: ChainFormat,
        pagination: EtherscanPagination
    ) -> BaseOperation<EtherscanNativeHistoryInfo> {
        ClosureOperation {
            let address = try accountId.toAddress(using: chainFormat)
            let ethereumAddress = address.toEthereumAddressWithChecksum() ?? address

            let info = EtherscanNativeHistoryInfo(
                address: ethereumAddress,
                page: pagination.page,
                offset: pagination.offset
            )

            return info
        }
    }

    func createFetchWrapper(
        for accountId: AccountId,
        chainFormat: ChainFormat,
        pagination: EtherscanPagination
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let infoOperation = createInfoOperation(
            accountId: accountId,
            chainFormat: chainFormat,
            pagination: pagination
        )

        let wrapper: CompoundOperationWrapper<WalletRemoteHistoryData>
        wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            let info = try infoOperation.extractNoCancellableResultData()

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

        wrapper.addDependency(operations: [infoOperation])

        return wrapper.insertingHead(operations: [infoOperation])
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
        chainFormat: ChainFormat,
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
