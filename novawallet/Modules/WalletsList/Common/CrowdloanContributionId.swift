import BigInt

struct CrowdloanContributionId {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let amount: BigUInt
}
