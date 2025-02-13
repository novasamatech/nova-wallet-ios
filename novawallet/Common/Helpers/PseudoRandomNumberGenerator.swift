struct SplitMix64Generator: RandomNumberGenerator {
    private var seed: UInt64

    init(seed: Int) {
        self.seed = UInt64(bitPattern: Int64(seed))
    }

    mutating func next() -> UInt64 {
        seed = seed &+ 0x9E37_79B9_7F4A_7C15
        var scrambledState = seed
        scrambledState = (scrambledState ^ (scrambledState >> 30)) &* 0xBF58_476D_1CE4_E5B9
        scrambledState = (scrambledState ^ (scrambledState >> 27)) &* 0x94D0_49BB_1331_11EB
        return scrambledState ^ (scrambledState >> 31)
    }
}
