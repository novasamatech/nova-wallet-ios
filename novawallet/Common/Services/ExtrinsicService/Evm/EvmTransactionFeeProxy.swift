import Foundation
import BigInt

protocol EvmTransactionFeeProxyDelegate: AnyObject {
    func didReceiveFee(result: Result<BigUInt, Error>, for identifier: TransactionFeeId)
}

protocol EvmTransactionFeeProxyProtocol: AnyObject {
    var delegate: EvmTransactionFeeProxyDelegate? { get set }

    func estimateFee(
        using service: EvmTransactionServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        setupBy closure: @escaping EvmTransactionBuilderClosure
    )
}

final class EvmTransactionFeeProxy: TransactionFeeProxy<BigUInt> {
    weak var delegate: EvmTransactionFeeProxyDelegate?

    let fallbackGasLimit: BigUInt

    init(fallbackGasLimit: BigUInt) {
        self.fallbackGasLimit = fallbackGasLimit
    }

    private func handle(result: Result<BigUInt, Error>, for identifier: TransactionFeeId) {
        update(result: result, for: identifier)

        delegate?.didReceiveFee(result: result, for: identifier)
    }
}

extension EvmTransactionFeeProxy: EvmTransactionFeeProxyProtocol {
    func estimateFee(
        using service: EvmTransactionServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        setupBy closure: @escaping EvmTransactionBuilderClosure
    ) {
        if let state = getCachedState(for: reuseIdentifier) {
            if case let .loaded(result) = state {
                delegate?.didReceiveFee(result: result, for: reuseIdentifier)
            }

            return
        }

        setCachedState(.loading, for: reuseIdentifier)

        service.estimateFee(closure, fallbackGasLimit: fallbackGasLimit, runningIn: .main) { [weak self] result in
            self?.handle(result: result, for: reuseIdentifier)
        }
    }
}
