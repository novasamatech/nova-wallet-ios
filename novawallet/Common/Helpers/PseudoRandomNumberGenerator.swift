struct PseudoRandomNumberGenerator: RandomNumberGenerator {
    private var seed: UInt64

    init(seed: Int) {
        self.seed = UInt64(bitPattern: Int64(seed))
    }

    mutating func next() -> UInt64 {
        seed ^= seed << 13
        seed ^= seed >> 7
        seed ^= seed << 17
        return seed
    }
}
