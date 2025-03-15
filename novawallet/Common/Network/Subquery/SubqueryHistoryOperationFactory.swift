import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubqueryHistoryOperationFactoryProtocol {
    func createOperation(
        accountId: AccountId,
        count: Int,
        cursor: String?
    ) -> BaseOperation<SubqueryHistoryData>
}

enum SubqueryHistoryError: Error {
    case requestFactoryCreation
}

final class SubqueryHistoryOperationFactory {
    let url: URL
    let filter: WalletHistoryFilter
    let assetId: String?
    let hasPoolStaking: Bool
    let hasSwaps: Bool
    let chainFormat: ChainFormat

    init(
        url: URL,
        filter: WalletHistoryFilter,
        assetId: String?,
        hasPoolStaking: Bool,
        hasSwaps: Bool,
        chainFormat: ChainFormat
    ) {
        self.url = url
        self.filter = filter
        self.assetId = assetId
        self.hasPoolStaking = hasPoolStaking
        self.hasSwaps = hasSwaps
        self.chainFormat = chainFormat
    }
}

// MARK: Private

private extension SubqueryHistoryOperationFactory {
    func prepareExtrinsicInclusionFilter() -> String {
        let transferCallNames = ["transfer", "transferKeepAlive", "forceTransfer", "transferAll", "transferAllowDeath"]

        let transferFilters = transferCallNames.map { transferCallName in
            SubqueryContainsFilter(
                fieldName: "extrinsic",
                inner: SubqueryValueFilter(fieldName: "call", value: transferCallName)
            )
        }

        let swapCallNames = ["swapExactTokensForTokens", "swapTokensForExactTokens"]

        let swapFilters = swapCallNames.map { swapCallName in
            SubqueryContainsFilter(
                fieldName: "extrinsic",
                inner: SubqueryValueFilter(fieldName: "call", value: swapCallName)
            )
        }

        return SubqueryInnerFilter(
            inner: SubqueryCompoundFilter.and(
                [
                    SubqueryIsNotNullFilter(fieldName: "extrinsic"),
                    SubqueryNotWithCompoundFilter(
                        inner: .or([
                            SubqueryCompoundFilter.and([
                                SubqueryContainsFilter(
                                    fieldName: "extrinsic",
                                    inner: SubqueryValueFilter(fieldName: "module", value: "balances")
                                ),
                                SubqueryCompoundFilter.or(transferFilters)
                            ]),
                            SubqueryCompoundFilter.and([
                                SubqueryContainsFilter(
                                    fieldName: "extrinsic",
                                    inner: SubqueryValueFilter(fieldName: "module", value: "assetConversion")
                                ),
                                SubqueryCompoundFilter.or(swapFilters)
                            ])
                        ])
                    )
                ]
            )
        ).rawSubqueryFilter()
    }

    func prepareAssetIdFilter(_ assetId: String) -> String {
        """
        {
            assetTransfer: { contains: {assetId: \"\(assetId)\"} }
        }
        """
    }

    func prepareSwapAssetIdFilter(_ assetId: String?) -> String {
        let assetIdOrNative = assetId ?? SubqueryHistoryElement.nativeFeeAssetId

        let filters = [
            SubqueryContainsFilter(
                fieldName: "swap",
                inner: SubqueryValueFilter(fieldName: "assetIdIn", value: assetIdOrNative)
            ),
            SubqueryContainsFilter(
                fieldName: "swap",
                inner: SubqueryValueFilter(fieldName: "assetIdOut", value: assetIdOrNative)
            )
        ]

        return SubqueryInnerFilter(inner: SubqueryCompoundFilter.or(filters)).rawSubqueryFilter()
    }

    func prepareFilter() -> String {
        var filterStrings: [String] = []

        if filter.contains(.extrinsics) {
            filterStrings.append(prepareExtrinsicInclusionFilter())
        }

        if filter.contains(.rewardsAndSlashes) {
            var childFilters: [SubqueryFilter] = [SubqueryIsNotNullFilter(fieldName: "reward")]

            if hasPoolStaking {
                childFilters.append(SubqueryIsNotNullFilter(fieldName: "poolReward"))
            }

            let filter = SubqueryInnerFilter(inner:
                SubqueryCompoundFilter.or(childFilters)
            )
            filterStrings.append(filter.rawSubqueryFilter())
        }

        if filter.contains(.transfers) {
            if let assetId = assetId {
                filterStrings.append(prepareAssetIdFilter(assetId))
            } else {
                filterStrings.append("{ transfer: { isNull: false } }")
            }
        }

        if filter.contains(.swaps), hasSwaps {
            filterStrings.append(prepareSwapAssetIdFilter(assetId))
        }

        return filterStrings.joined(separator: ",")
    }

    func createQuery(
        _ accountId: AccountId,
        count: Int,
        cursor: String?
    ) throws -> String {
        var address = try accountId.toAddress(using: chainFormat)
        var legacyAddress = try address.toLegacySubstrateAddress(for: chainFormat)

        if case .ethereum = chainFormat {
            address = address.toEthereumAddressWithChecksum() ?? address
            legacyAddress = legacyAddress?.toEthereumAddressWithChecksum() ?? legacyAddress
        }

        let after = cursor.map { "\"\($0)\"" } ?? "null"
        let transferField = assetId != nil ? "assetTransfer" : "transfer"
        let filterString = prepareFilter()
        let poolRewardField = hasPoolStaking ? "poolReward" : ""
        let swapField = hasSwaps ? "swap" : ""
        let addressFilter = if let legacyAddress {
            "address: { in: [\"\(address)\", \"\(legacyAddress)\"] }"
        } else {
            "address: { equalTo: \"\(address)\"}"
        }

        return """
        {
            historyElements(
                 after: \(after),
                 first: \(count),
                 orderBy: TIMESTAMP_DESC,
                 filter: {
                     \(addressFilter),
                     or: [
                        \(filterString)
                     ]
                 }
             ) {
                 pageInfo {
                     startCursor,
                     endCursor
                 },
                 nodes {
                     id
                     blockNumber
                     extrinsicIdx
                     extrinsicHash
                     timestamp
                     address
                     reward
                     extrinsic
                     \(transferField)
                     \(poolRewardField)
                     \(swapField)
                 }
             }
        }
        """
    }

    func createRequestFactory(
        accountId: AccountId,
        count: Int,
        cursor: String?
    ) throws -> BlockNetworkRequestFactory {
        let queryString = try createQuery(
            accountId,
            count: count,
            cursor: cursor
        )

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue

            return request
        }

        return requestFactory
    }
}

extension SubqueryHistoryOperationFactory: SubqueryHistoryOperationFactoryProtocol {
    func createOperation(
        accountId: AccountId,
        count: Int,
        cursor: String?
    ) -> BaseOperation<SubqueryHistoryData> {
        guard let requestFactory = try? createRequestFactory(
            accountId: accountId,
            count: count,
            cursor: cursor
        ) else {
            return .createWithError(SubqueryHistoryError.requestFactoryCreation)
        }

        let processResultBlock = createProcessingBlock()
        let resultFactory = AnyNetworkResultFactory(block: processResultBlock)

        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return operation
    }

    private func createProcessingBlock() -> NetworkResultFactoryBlock<SubqueryHistoryData> {
        { data, response, error in
            if let connectionError = error {
                return .failure(connectionError)
            }

            if let error = Self.createError(from: response) {
                return .failure(error)
            }

            guard let data = data else {
                return .failure(NetworkBaseError.unexpectedEmptyData)
            }

            do {
                let history = try Self.decodeHistory(from: data)
                return .success(history)
            } catch {
                return .failure(error)
            }
        }
    }

    private static func decodeHistory(from data: Data) throws -> SubqueryHistoryData {
        let response = try JSONDecoder().decode(
            SubqueryResponse<SubqueryHistoryData>.self,
            from: data
        )
        switch response {
        case let .errors(error):
            throw error
        case let .data(response):
            return response
        }
    }

    private static func createError(from response: URLResponse?) -> Error? {
        guard let httpUrlResponse = response as? HTTPURLResponse else {
            return NetworkBaseError.unexpectedResponseObject
        }

        switch httpUrlResponse.statusCode {
        case 200, 201:
            return nil
        case 400:
            return NetworkResponseError.invalidParameters
        case 401:
            return NetworkResponseError.authorizationError
        case 404:
            return NetworkResponseError.resourceNotFound
        case 500:
            return NetworkResponseError.internalServerError
        default:
            return NetworkResponseError.unexpectedStatusCode
        }
    }
}
