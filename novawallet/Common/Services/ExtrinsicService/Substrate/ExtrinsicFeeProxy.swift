import Foundation

protocol ExtrinsicFeeProxyDelegate: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for identifier: TransactionFeeId)
}

protocol ExtrinsicFeeProxyProtocol: AnyObject {
    var delegate: ExtrinsicFeeProxyDelegate? { get set }

    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    )
}

final class ExtrinsicFeeProxy: TransactionFeeProxy<RuntimeDispatchInfo> {
    weak var delegate: ExtrinsicFeeProxyDelegate?

    private func handle(result: Result<RuntimeDispatchInfo, Error>, for identifier: TransactionFeeId) {
        update(result: result, for: identifier)

        delegate?.didReceiveFee(result: result, for: identifier)
    }
}

extension ExtrinsicFeeProxy: ExtrinsicFeeProxyProtocol {
    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    ) {
        if let state = getCachedState(for: reuseIdentifier) {
            if case let .loaded(result) = state {
                delegate?.didReceiveFee(result: result, for: reuseIdentifier)
            }

            return
        }

        setCachedState(.loading, for: reuseIdentifier)

        service.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.handle(result: result, for: reuseIdentifier)
        }
    }
}
