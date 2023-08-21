import Foundation
import RobinHood
import BigInt

protocol EvmNonceProviderProtocol {
    func getNonceWrapper(
        for accountAddress: Data,
        block: EthereumBlock
    ) -> CompoundOperationWrapper<BigUInt>
}
