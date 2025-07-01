import BigInt

struct MultisigDepositCalculator {
    var base: BigUInt?
    var factor: BigUInt?
    var threshold: Int?

    func calculate() -> BigUInt? {
        guard let base, let factor, let threshold else {
            return nil
        }

        return base + factor * BigUInt(threshold)
    }
}
