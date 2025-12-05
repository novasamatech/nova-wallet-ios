import Foundation

struct EvmTransactionMonitorTimeout {
    let maxBlocks: Int

    static let `default` = EvmTransactionMonitorTimeout(maxBlocks: 10)

    static func blocks(_ count: Int) -> EvmTransactionMonitorTimeout {
        EvmTransactionMonitorTimeout(maxBlocks: count)
    }

    static let none = EvmTransactionMonitorTimeout(maxBlocks: Int.max)
}
