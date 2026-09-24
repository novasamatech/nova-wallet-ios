import SubstrateSdk

extension MultisigPallet {
    struct NewMultisigEvent: Decodable {
        let approvingAccountId: AccountId
        let accountId: AccountId
        let callHash: Substrate.CallHash

        init(from decoder: any Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            approvingAccountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            callHash = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
        }
    }

    struct MultisigApprovalEvent: Decodable {
        let approvingAccountId: AccountId
        let timepoint: EventTimePoint
        let accountId: AccountId
        let callHash: Substrate.CallHash

        init(from decoder: any Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            approvingAccountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            timepoint = try unkeyedContainer.decode(EventTimePoint.self)
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            callHash = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
        }
    }

    struct MultisigExecutedEvent: Decodable {
        let approvingAccountId: AccountId
        let timepoint: EventTimePoint
        let accountId: AccountId
        let callHash: Substrate.CallHash
        let result: Substrate.Result<JSON, JSON>

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            approvingAccountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            timepoint = try unkeyedContainer.decode(EventTimePoint.self)
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            callHash = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            result = try unkeyedContainer.decode(Substrate.Result<JSON, JSON>.self)
        }
    }
}
