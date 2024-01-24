import Foundation
import BigInt

protocol XcmExtrinsicFeeProxyDelegate: AnyObject {
    func didReceiveOriginFee(result: XcmTrasferOriginFeeResult, for identifier: TransactionFeeId)
    func didReceiveCrossChainFee(result: XcmTrasferCrosschainFeeResult, for identifier: TransactionFeeId)
}

protocol XcmExtrinsicFeeProxyProtocol: AnyObject {
    var delegate: XcmExtrinsicFeeProxyDelegate? { get set }

    func estimateOriginFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: TransactionFeeId
    )

    func estimateCrossChainFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: TransactionFeeId
    )
}

final class XcmExtrinsicFeeProxy {
    enum State<FeeType> {
        case loading
        case loaded(result: Result<FeeType, Error>)
    }

    private var originFeeStore: [TransactionFeeId: State<ExtrinsicFeeProtocol>] = [:]
    private var crosschainFeeStore: [TransactionFeeId: State<XcmFeeModelProtocol>] = [:]

    weak var delegate: XcmExtrinsicFeeProxyDelegate?

    private func handleOrigin(
        result: Result<ExtrinsicFeeProtocol, Error>,
        for identifier: TransactionFeeId
    ) {
        switch result {
        case .success:
            originFeeStore[identifier] = .loaded(result: result)
        case .failure:
            originFeeStore[identifier] = nil
        }

        delegate?.didReceiveOriginFee(result: result, for: identifier)
    }

    private func handleCrosschain(
        result: Result<XcmFeeModelProtocol, Error>,
        for identifier: TransactionFeeId
    ) {
        switch result {
        case .success:
            crosschainFeeStore[identifier] = .loaded(result: result)
        case .failure:
            crosschainFeeStore[identifier] = nil
        }

        delegate?.didReceiveCrossChainFee(result: result, for: identifier)
    }
}

extension XcmExtrinsicFeeProxy: XcmExtrinsicFeeProxyProtocol {
    func estimateOriginFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: TransactionFeeId
    ) {
        if let state = originFeeStore[reuseIdentifier] {
            if case let .loaded(result) = state {
                delegate?.didReceiveOriginFee(result: result, for: reuseIdentifier)
            }

            return
        }

        originFeeStore[reuseIdentifier] = .loading

        service.estimateOriginFee(
            request: xcmTransferRequest,
            xcmTransfers: xcmTransfers,
            runningIn: .main
        ) { [weak self] result in
            self?.handleOrigin(result: result, for: reuseIdentifier)
        }
    }

    func estimateCrossChainFee(
        using service: XcmTransferServiceProtocol,
        xcmTransferRequest: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        reuseIdentifier: TransactionFeeId
    ) {
        if let state = crosschainFeeStore[reuseIdentifier] {
            if case let .loaded(result) = state {
                delegate?.didReceiveCrossChainFee(result: result, for: reuseIdentifier)
            }

            return
        }

        crosschainFeeStore[reuseIdentifier] = .loading

        service.estimateCrossChainFee(
            request: xcmTransferRequest,
            xcmTransfers: xcmTransfers,
            runningIn: .main
        ) { [weak self] result in
            self?.handleCrosschain(result: result, for: reuseIdentifier)
        }
    }
}
