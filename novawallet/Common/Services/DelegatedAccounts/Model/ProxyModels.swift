import SubstrateSdk

protocol DiscoveredDelegatedAccountProtocol {
    var accountId: AccountId { get }
    var delegateAccountId: AccountId { get }
}

struct ProxiedAccount: DiscoveredDelegatedAccountProtocol, Hashable {
    var delegateAccountId: AccountId {
        proxyAccount.accountId
    }

    let accountId: AccountId
    let proxyAccount: ProxyAccount
}

struct ProxyAccount: Hashable {
    let accountId: AccountId
    let type: Proxy.ProxyType
    let delay: BlockNumber

    var hasDelay: Bool {
        delay > 0
    }
}

struct AccountIdKey: JSONListConvertible, Hashable {
    let accountId: AccountId

    init(accountId: AccountId) {
        self.accountId = accountId
    }

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        let expectedFieldsCount = 1
        let actualFieldsCount = jsonList.count
        guard expectedFieldsCount == actualFieldsCount else {
            throw JSONListConvertibleError.unexpectedNumberOfItems(
                expected: expectedFieldsCount,
                actual: actualFieldsCount
            )
        }

        accountId = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
    }
}

struct ProxyDefinition: Decodable, Equatable {
    let definition: [Proxy.ProxyDefinition]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        definition = try container.decode([Proxy.ProxyDefinition].self)
    }

    init(definition: [Proxy.ProxyDefinition]) {
        self.definition = definition
    }
}

enum ProxyFilter {
    static func filteredStakingProxy(from proxy: ProxyDefinition) -> ProxyDefinition {
        ProxyDefinition(definition: proxy.definition.filter { $0.proxyType == .staking })
    }

    static func allProxies(from proxy: ProxyDefinition) -> ProxyDefinition {
        proxy
    }
}
