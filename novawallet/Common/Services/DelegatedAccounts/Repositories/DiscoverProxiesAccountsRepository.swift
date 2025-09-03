import Foundation
import Operation_iOS
import SubstrateSdk

final class DiscoverProxiesAccountsRepository: SubqueryBaseOperationFactory {
    struct Response: Decodable {
        let proxieds: SubqueryNodes<Proxied>
    }

    struct Proxied: Decodable {
        @HexCodable var chainId: Data
        let type: String
        @HexCodable var proxyAccountId: AccountId
        @HexCodable var accountId: Data
    }
}

private extension DiscoverProxiesAccountsRepository {
    func createQuery(for accountIds: Set<AccountId>) -> String {
        let filter = SubqueryFilterBuilder.buildBlock(
            SubqueryCompoundFilter.and(
                [
                    SubqueryEqualToFilter(
                        fieldName: "delay",
                        value: SubqueryStringConvertibleValue(value: 0)
                    ),
                    SubqueryFieldInFilter(
                        fieldName: "proxyAccountId",
                        values: accountIds.map { $0.toHexWithPrefix() }
                    )
                ]
            )
        )

        return """
        {
            proxieds(
                \(filter)
            ) {
                nodes {
                    chainId
                    type
                    proxyAccountId
                    accountId
                }
            }
        }
        """
    }
}

extension DiscoverProxiesAccountsRepository: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegateMapping> {
        let query = createQuery(for: accountIds)

        let queryOperation: BaseOperation<DelegatedAccountsByDelegateMapping> = createOperation(
            for: query
        ) { (response: Response) in
            let proxyToProxieds = response.proxieds.nodes.reduce(
                into: [AccountId: Set<DiscoveredAccount.ProxiedModel>]()
            ) { accum, node in
                let newModel = DiscoveredAccount.ProxiedModel(subqueryModel: node)

                let prevSet = accum[node.proxyAccountId]
                accum[node.proxyAccountId] = (prevSet ?? []).union([newModel])
            }

            return proxyToProxieds
                .mapValues { Array($0) }
                .filter { accountIds.contains($0.key) }
        }

        return CompoundOperationWrapper(targetOperation: queryOperation)
    }
}

private extension DiscoveredAccount.ProxiedModel {
    init(subqueryModel: DiscoverProxiesAccountsRepository.Proxied) {
        chainId = subqueryModel.chainId.toHex(includePrefix: false)
        type = Proxy.ProxyType(rawType: subqueryModel.type)
        proxyAccountId = subqueryModel.proxyAccountId
        proxiedAccountId = subqueryModel.accountId
    }
}
