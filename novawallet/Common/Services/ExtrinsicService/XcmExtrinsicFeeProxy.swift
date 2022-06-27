import Foundation
import BigInt

protocol XcmExtrinsicFeeProxyDelegate: AnyObject {
    func didReceiveOriginFee(result: XcmTrasferFeeResult, for identifier: ExtrinsicFeeId)
    func didReceiveCrossChainFee(result: XcmTrasferFeeResult, for identifier: ExtrinsicFeeId)
}

protocol XcmExtrinsicFeeProxyProtocol: AnyObject {
    var delegate: XcmExtrinsicFeeProxyDelegate? { get set }

    func estimateOriginFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: ExtrinsicFeeId
    )

    func estimateCrossChainFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: ExtrinsicFeeId
    )
}

final class XcmExtrinsicFeeProxy {
    enum State {
        case loading
        case loaded(result: Result<FeeWithWeight, Error>)
    }

    private var feeStore: [ExtrinsicFeeId: State] = [:]

    weak var delegate: XcmExtrinsicFeeProxyDelegate?

    private func handle(
        result: Result<FeeWithWeight, Error>,
        for identifier: ExtrinsicFeeId,
        origin: Bool
    ) {
        switch result {
        case .success:
            feeStore[identifier] = .loaded(result: result)
        case .failure:
            feeStore[identifier] = nil
        }

        if origin {
            delegate?.didReceiveOriginFee(result: result, for: identifier)
        } else {
            delegate?.didReceiveCrossChainFee(result: result, for: identifier)
        }
    }
}

extension XcmExtrinsicFeeProxy: XcmExtrinsicFeeProxyProtocol {
    func estimateOriginFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: ExtrinsicFeeId
    ) {
        if let state = feeStore[reuseIdentifier] {
            if case let .loaded(result) = state {
                delegate?.didReceiveOriginFee(result: result, for: reuseIdentifier)
            }

            return
        }

        feeStore[reuseIdentifier] = .loading

        service.estimateOriginFee(
            request: xcmTransferRequest,
            xcmTransfers: xcmTransfers,
            runningIn: .main
        ) { [weak self] result in
            self?.handle(result: result, for: reuseIdentifier, origin: true)
        }
    }

    func estimateCrossChainFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: ExtrinsicFeeId
    ) {
        if let state = feeStore[reuseIdentifier] {
            if case let .loaded(result) = state {
                delegate?.didReceiveCrossChainFee(result: result, for: reuseIdentifier)
            }

            return
        }

        feeStore[reuseIdentifier] = .loading

        service.estimateCrossChainFee(
            request: xcmTransferRequest,
            xcmTransfers: xcmTransfers,
            runningIn: .main
        ) { [weak self] result in
            self?.handle(result: result, for: reuseIdentifier, origin: false)
        }
    }
}
