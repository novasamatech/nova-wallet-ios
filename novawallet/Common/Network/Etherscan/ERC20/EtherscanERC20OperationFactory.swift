import Foundation
import Operation_iOS
import SoraFoundation

final class EtherscanERC20OperationFactory: EtherscanBaseOperationFactory {
    let contractAddress: AccountAddress

    init(
        contractAddress: AccountAddress,
        baseUrl: URL,
        chainId: ChainModel.Id,
        operationManager: OperationManagerProtocol
    ) {
        self.contractAddress = contractAddress

        super.init(
            baseUrl: baseUrl,
            chainId: chainId,
            operationManager: operationManager
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

    func createInfoOperation(
        accountId: AccountId,
        chainFormat: ChainFormat,
        pagination: EtherscanPagination
    ) -> BaseOperation<EtherscanERC20HistoryInfo> {
        ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

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
                responseType: EtherscanERC20HistoryResponse.self
            )
        }

        wrapper.addDependency(operations: [infoOperation])

        return wrapper.insertingHead(operations: [infoOperation])
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
        chainFormat: ChainFormat,
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
