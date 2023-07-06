import BigInt

enum StartStakingType {
    case nominationPool
    case directStaking(amount: BigUInt)
}
