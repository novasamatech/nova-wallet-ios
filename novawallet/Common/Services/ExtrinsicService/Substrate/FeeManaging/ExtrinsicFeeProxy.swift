import Foundation

protocol ExtrinsicFeeProxyDelegate: AnyObject {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for identifier: TransactionFeeId)
}

protocol ExtrinsicFeeProxyProtocol: AnyObject {
    var delegate: ExtrinsicFeeProxyDelegate? { get set }

    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        payingIn chainAssetId: ChainAssetId?,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    )
}

extension ExtrinsicFeeProxyProtocol {
    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        payingIn assetId: ChainAssetId? = nil,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    ) {
        estimateFee(
            using: service,
            reuseIdentifier: reuseIdentifier,
            payingIn: assetId,
            setupBy: closure
        )
    }
}

final class ExtrinsicFeeProxy: TransactionFeeProxy<ExtrinsicFeeProtocol> {
    weak var delegate: ExtrinsicFeeProxyDelegate?

    private func handle(result: Result<ExtrinsicFeeProtocol, Error>, for stateKey: StateKey) {
        update(result: result, for: stateKey)

        delegate?.didReceiveFee(result: result, for: stateKey.reuseIdentifier)
    }
}

extension ExtrinsicFeeProxy: ExtrinsicFeeProxyProtocol {
    func estimateFee(
        using service: ExtrinsicServiceProtocol,
        reuseIdentifier: TransactionFeeId,
        payingIn chainAssetId: ChainAssetId?,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    ) {
        let stateKey = StateKey(reuseIdentifier: reuseIdentifier, chainAssetId: chainAssetId)

        if let state = getCachedState(for: stateKey) {
            if case let .loaded(result) = state {
                delegate?.didReceiveFee(result: result, for: reuseIdentifier)
            }

            return
        }

        setCachedState(.loading, for: stateKey)

        service.estimateFee(
            closure,
            payingIn: chainAssetId,
            runningIn: .main
        ) { [weak self] result in
            self?.handle(
                result: result,
                for: stateKey
            )
        }
    }
}
