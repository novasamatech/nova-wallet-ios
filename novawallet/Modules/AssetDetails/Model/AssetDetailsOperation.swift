import Foundation

struct AssetDetailsOperation: OptionSet {
    let rawValue: Int

    static let send = AssetDetailsOperation(rawValue: 1 << 0)
    static let receive = AssetDetailsOperation(rawValue: 1 << 1)
    static let buy = AssetDetailsOperation(rawValue: 1 << 2)
    static let sell = AssetDetailsOperation(rawValue: 1 << 3)
    static let swap = AssetDetailsOperation(rawValue: 1 << 4)
}
