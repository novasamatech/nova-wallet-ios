import Foundation
import BigInt

protocol MultiExtrinsicFeeProxyDelegate: AnyObject {
    func didReceiveTotalFee(result: Result<BigUInt, Error>, for identifier: TransactionFeeId)
}

protocol MultiExtrinsicFeeProxyProtocol: AnyObject {
    var delegate: MultiExtrinsicFeeProxyDelegate? { get set }

    func estimateFee(
        from extrinsicSplitter: ExtrinsicSplitting,
        service: ExtrinsicServiceProtocol,
        reuseIdentifier: TransactionFeeId
    )
}

final class MultiExtrinsicFeeProxy: TransactionFeeProxy<BigUInt> {
    weak var delegate: MultiExtrinsicFeeProxyDelegate?

    private func handle(results: [Result<ExtrinsicFeeProtocol, Error>], for identifier: TransactionFeeId) {
        do {
            let totalFee = try results.reduce(BigUInt(0)) { accum, result in
                let newFeeInfo = try result.get()
                return accum + newFeeInfo.amount
            }

            update(result: .success(totalFee), for: identifier)

            delegate?.didReceiveTotalFee(result: .success(totalFee), for: identifier)
        } catch {
            update(result: .failure(error), for: identifier)

            delegate?.didReceiveTotalFee(result: .failure(error), for: identifier)
        }
    }
}

extension MultiExtrinsicFeeProxy: MultiExtrinsicFeeProxyProtocol {
    func estimateFee(
        from extrinsicSplitter: ExtrinsicSplitting,
        service: ExtrinsicServiceProtocol,
        reuseIdentifier: TransactionFeeId
    ) {
        if let state = getCachedState(for: reuseIdentifier) {
            if case let .loaded(result) = state {
                delegate?.didReceiveTotalFee(result: result, for: reuseIdentifier)
            }

            return
        }

        setCachedState(.loading, for: reuseIdentifier)

        service.estimateFeeWithSplitter(
            extrinsicSplitter,
            runningIn: .main
        ) { [weak self] result in
            self?.handle(results: result.results.map(\.result), for: reuseIdentifier)
        }
    }
}
