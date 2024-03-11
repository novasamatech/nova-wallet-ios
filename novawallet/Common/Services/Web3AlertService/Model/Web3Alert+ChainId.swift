import Foundation
import SubstrateSdk

extension Web3Alert {
    static func createRemoteChainId(from chainId: Web3Alert.LocalChainId) -> Web3Alert.RemoteChainId {
        let size = 32
        guard chainId.count >= size else {
            return chainId
        }

        return String(chainId.prefix(size)).stripHexPrefix().addHexPrefix()
    }
}
