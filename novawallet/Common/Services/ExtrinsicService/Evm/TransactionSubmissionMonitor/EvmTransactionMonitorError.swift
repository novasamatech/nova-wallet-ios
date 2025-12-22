import Foundation
import BigInt

enum EvmTransactionMonitorError: Error {
    case timeout(blocksWaited: BigUInt)
}
