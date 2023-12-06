import SubstrateSdk

struct ProxiedAccount {
    let accountId: AccountId
    let type: Proxy.ProxyType
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

        accountId = try jsonList[0].map(to: AccountId.self, with: context)
    }
}

struct ProxyDefinition: Decodable {
    let definition: [Proxy.ProxyDefinition]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        definition = try container.decode([Proxy.ProxyDefinition].self)
    }
}
