import SubstrateSdk

struct ProxyAccount {
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

extension ProxyDefinition {
    func filterStakingProxy() -> ProxyDefinition {
        .init(definition: definition.filter { $0.proxyType.allowStaking })
    }
}
