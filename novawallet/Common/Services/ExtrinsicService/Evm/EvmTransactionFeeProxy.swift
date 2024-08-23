import Foundation
import BigInt

protocol EvmTransactionFeeProxyDelegate: AnyObject {
    func didReceiveFee(result: Result<EvmFeeModel, Error>, for identifier: TransactionFeeId)
}

protocol EvmTransactionFeeProxyProtocol: AnyObject {
    var delegate: EvmTransactionFeeProxyDelegate? { get set }

    func estimateFee(
        using service: EvmTransactionServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        setupBy closure: @escaping EvmTransactionBuilderClosure
    )
}

final class EvmTransactionFeeProxy: TransactionFeeProxy<EvmFeeModel> {
    weak var delegate: EvmTransactionFeeProxyDelegate?

    private func handle(result: Result<EvmFeeModel, Error>, for stateKey: StateKey) {
        update(result: result, for: stateKey)

        delegate?.didReceiveFee(result: result, for: stateKey.reuseIdentifier)
    }
}

extension EvmTransactionFeeProxy: EvmTransactionFeeProxyProtocol {
    func estimateFee(
        using service: EvmTransactionServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        setupBy closure: @escaping EvmTransactionBuilderClosure
    ) {
        let stateKey = StateKey(reuseIdentifier: reuseIdentifier, chainAssetId: nil)

        if let state = getCachedState(for: stateKey) {
            if case let .loaded(result) = state {
                delegate?.didReceiveFee(result: result, for: reuseIdentifier)
            }

            return
        }

        setCachedState(.loading, for: stateKey)

        service.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.handle(result: result, for: stateKey)
        }
    }
}
