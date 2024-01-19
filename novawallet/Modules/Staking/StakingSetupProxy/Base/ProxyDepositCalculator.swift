import BigInt

struct ProxyDepositCalculator {
    var base: BigUInt?
    var factor: BigUInt?
    var proxyCount: Int?

    func calculate() -> ProxyDeposit? {
        guard let base = self.base, let factor = self.factor, let proxyCount = self.proxyCount else {
            return nil
        }

        let currentDeposit = proxyCount > 0 ? calculate(base: base, factor: factor, proxyCount: proxyCount) : 0
        let newDeposit = calculate(base: base, factor: factor, proxyCount: proxyCount + 1)

        return .init(
            current: currentDeposit,
            new: newDeposit
        )
    }

    func calculate(base: BigUInt, factor: BigUInt, proxyCount: Int) -> BigUInt {
        base + BigUInt(proxyCount) * factor
    }
}

struct ProxyDeposit {
    let current: BigUInt
    let new: BigUInt

    var diff: BigUInt {
        guard new > current else {
            return 0
        }
        return new - current
    }
}
