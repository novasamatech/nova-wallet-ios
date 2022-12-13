import Foundation
import SubstrateSdk

extension JSONRPCError {
    var isEvmContractReverted: Bool { code == -32603 }
}
