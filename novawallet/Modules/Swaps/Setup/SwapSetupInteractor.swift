import UIKit
import RobinHood
import BigInt

final class SwapSetupInteractor: AnyCancellableCleaning {
    weak var presenter: SwapSetupInteractorOutputProtocol?
    let assetConversionOperationFactory: AssetConversionOperationFactoryProtocol
    let assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol
    let runtimeService: RuntimeProviderProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol

    private let operationQueue: OperationQueue
    private var quoteCall: CancellableCall?
    private var runtimeOperationCall: CancellableCall?

    init(
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionExtrinsicService: AssetConversionExtrinsicServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.assetConversionOperationFactory = assetConversionOperationFactory
        self.assetConversionExtrinsicService = assetConversionExtrinsicService
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.operationQueue = operationQueue
    }

    private func quote(args: AssetConversion.QuoteArgs) {
        clear(cancellable: &quoteCall)

        let wrapper = assetConversionOperationFactory.quote(for: args)
        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.quoteCall === wrapper else {
                    return
                }
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceive(quote: result)
                } catch {
                    self?.presenter?.didReceive(error: .quote(error))
                }
            }
        }

        quoteCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func extrinsicService() -> ExtrinsicServiceProtocol? {
        nil
    }

    private func fee(args: AssetConversion.CallArgs) {
        clear(cancellable: &runtimeOperationCall)
        guard let extrinsicService = extrinsicService() else {
            presenter?.didReceive(error: .fetchFeeFailed(CommonError.undefined))
            return
        }

        let runtimeCoderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        runtimeCoderFactoryOperation.completionBlock = { [weak self] in
            guard let self = self else {
                return
            }
            do {
                let runtimeCoderFactory = try runtimeCoderFactoryOperation.extractNoCancellableResultData()
                let builder = self.assetConversionExtrinsicService.fetchExtrinsicBuilderClosure(
                    for: args,
                    codingFactory: runtimeCoderFactory
                )
                self.feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: "", setupBy: builder)
            } catch {
                DispatchQueue.main.async {
                    self.presenter?.didReceive(error: .fetchFeeFailed(error))
                }
            }
        }

        runtimeOperationCall = runtimeCoderFactoryOperation
        operationQueue.addOperation(runtimeCoderFactoryOperation)
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
    }

    func calculateQuote(for args: AssetConversion.QuoteArgs) {
        quote(args: args)
    }
}

extension SwapSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(dispatchInfo):
            let fee = BigUInt(dispatchInfo.fee)
            presenter?.didReceive(fee: fee)
        case let .failure(error):
            presenter?.didReceive(error: .fetchFeeFailed(error))
        }
    }
}
