import BigInt

struct MinStakeCrossedParams {
    let stakedAmountInPlank: BigUInt?
    let minStake: BigUInt?
    let unstakeAllHandler: () -> Void
}
