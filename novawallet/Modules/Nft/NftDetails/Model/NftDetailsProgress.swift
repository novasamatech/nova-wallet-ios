import Foundation

struct NftDetailsProgress: OptionSet {
    typealias RawValue = UInt16

    static let name = NftDetailsProgress(rawValue: 1 << 0)
    static let label = NftDetailsProgress(rawValue: 1 << 1)
    static let description = NftDetailsProgress(rawValue: 1 << 2)
    static let media = NftDetailsProgress(rawValue: 1 << 3)
    static let price = NftDetailsProgress(rawValue: 1 << 4)
    static let collection = NftDetailsProgress(rawValue: 1 << 5)
    static let owner = NftDetailsProgress(rawValue: 1 << 6)
    static let issuer = NftDetailsProgress(rawValue: 1 << 7)
    static let all = NftDetailsProgress(rawValue: (1 << 8) - 1)

    let rawValue: UInt16

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}
