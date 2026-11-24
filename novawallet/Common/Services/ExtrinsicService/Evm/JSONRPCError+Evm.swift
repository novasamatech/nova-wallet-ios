import Foundation
import SubstrateSdk

extension JSONRPCError {
    var isEvmContractReverted: Bool { code == -32603 }

    var isDefinitiveEvmSendRejection: Bool {
        let normalizedMessage = message.lowercased().replacingOccurrences(of: "_", with: " ")

        guard !EvmSendRejectionMarkers.uncertain.contains(where: { normalizedMessage.contains($0) }) else {
            return false
        }

        return EvmSendRejectionMarkers.definitive.contains(where: { normalizedMessage.contains($0) })
    }
}

private enum EvmSendRejectionMarkers {
    static let uncertain: [String] = [
        "already known",
        "alreadyknown",
        "known transaction",
        "already imported",
        "nonce too low",
        "oldnonce",
        "replacement transaction underpriced",
        "gas price too low to replace"
    ]

    static let definitive: [String] = [
        "insufficient funds",
        "underpriced",
        "less than block base fee",
        "intrinsic gas too low",
        "exceeds block gas limit",
        "higher than max fee per gas",
        "exceeds the configured cap",
        "invalid sender",
        "invalid signature",
        "invalid chain id",
        "only replay-protected",
        "oversized data"
    ]
}
