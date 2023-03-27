import Foundation

protocol MultiExtrinsicSubmitRetryInputProtocol: AnyObject {
    var extrinsicService: ExtrinsicServiceProtocol { get }
    var signer: SigningWrapperProtocol { get }

    func retryMultiExtrinsic(for closure: @escaping ExtrinsicBuilderIndexedClosure, indexes: IndexSet)
    func handleMultiExtrinsicSubmission(result: SubmitIndexedExtrinsicResult)
}

extension MultiExtrinsicSubmitRetryInputProtocol {
    func retryMultiExtrinsic(for closure: @escaping ExtrinsicBuilderIndexedClosure, indexes: IndexSet) {
        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main,
            indexes: indexes
        ) { [weak self] result in
            self?.handleMultiExtrinsicSubmission(result: result)
        }
    }
}
