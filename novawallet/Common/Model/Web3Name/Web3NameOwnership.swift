import SubstrateSdk
import BigInt

struct Web3NameOwnership: Codable {
    let owner: AccountId
    @StringCodable var claimedAt: BigUInt
    let deposit: Deposit

    struct Deposit: Codable {
        let owner: AccountId
        @StringCodable var amount: BigUInt
    }
}
