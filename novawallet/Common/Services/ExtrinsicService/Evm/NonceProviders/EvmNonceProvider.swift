import Foundation
import Operation_iOS
import BigInt

protocol EvmNonceProviderProtocol {
    func getNonceWrapper(
        for accountAddress: Data,
        block: EthereumBlock
    ) -> CompoundOperationWrapper<BigUInt>
}
