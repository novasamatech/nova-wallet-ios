import Foundation

struct Operations: OptionSet {
    let rawValue: Int

    static let send = Operations(rawValue: 1 << 0)
    static let receive = Operations(rawValue: 1 << 1)
    static let buy = Operations(rawValue: 1 << 2)
}
