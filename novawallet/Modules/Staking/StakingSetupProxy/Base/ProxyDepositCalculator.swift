import BigInt

struct ProxyDepositCalculator {
    var base: BigUInt?
    var factor: BigUInt?
    var proxyCount: Int?

    func calculate() -> BigUInt? {
        guard let base = self.base, let factor = self.factor, let proxyCount = self.proxyCount else {
            return nil
        }

        let currentDeposit = base + BigUInt(proxyCount) * factor
        let newDeposit = base + BigUInt(proxyCount + 1) * factor

        return newDeposit - currentDeposit
    }
}
