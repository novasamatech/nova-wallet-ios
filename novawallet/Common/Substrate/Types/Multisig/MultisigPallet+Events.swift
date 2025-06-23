import SubstrateSdk

extension MultisigPallet {
    struct NewMultisigEvent: Decodable {
        enum CodingKeys: String, CodingKey {
            case approvingAccountId = "approving"
            case accountId = "multisig"
            case callHash = "call_hash"
        }

        @BytesCodable var approvingAccountId: AccountId
        @BytesCodable var accountId: AccountId
        @BytesCodable var callHash: CallHash
    }

    struct MultisigApprovalEvent: Decodable {
        enum CodingKeys: String, CodingKey {
            case approvingAccountId = "approving"
            case timepoint
            case accountId = "multisig"
            case callHash = "call_hash"
        }

        @BytesCodable var approvingAccountId: AccountId
        let timepoint: MultisigPallet.MultisigTimepoint
        @BytesCodable var accountId: AccountId
        @BytesCodable var callHash: CallHash
    }
}
