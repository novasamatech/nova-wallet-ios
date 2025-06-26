import SubstrateSdk

extension MultisigPallet {
    struct NewMultisigEvent: Decodable {
        let approvingAccountId: AccountId
        let accountId: AccountId
        let callHash: CallHash

        init(from decoder: any Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            approvingAccountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            callHash = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
        }
    }

    struct MultisigApprovalEvent: Decodable {
        let approvingAccountId: AccountId
        let timepoint: MultisigPallet.MultisigTimepoint
        let accountId: AccountId
        let callHash: CallHash

        init(from decoder: any Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            approvingAccountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            timepoint = try unkeyedContainer.decode(MultisigPallet.MultisigTimepoint.self)
            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            callHash = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
        }
    }
}
