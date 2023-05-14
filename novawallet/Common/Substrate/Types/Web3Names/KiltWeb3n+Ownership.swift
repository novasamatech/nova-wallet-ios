import SubstrateSdk
import BigInt

extension KiltW3n {
    struct Ownership: Codable {
        let owner: AccountId
        @StringCodable var claimedAt: BigUInt
        let deposit: Deposit

        struct Deposit: Codable {
            let owner: AccountId
            @StringCodable var amount: BigUInt
        }
    }
}
