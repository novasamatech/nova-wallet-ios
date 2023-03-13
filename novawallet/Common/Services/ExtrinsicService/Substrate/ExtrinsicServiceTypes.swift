import Foundation
import SubstrateSdk

struct ExtrinsicRetriableResult<R> {
    struct IndexedResult {
        let index: Int
        let result: Result<R, Error>
    }

    let builderClosure: ExtrinsicBuilderIndexedClosure?
    let results: [IndexedResult]

    init(
        builderClosure: ExtrinsicBuilderIndexedClosure?,
        results: [IndexedResult]
    ) {
        self.builderClosure = builderClosure
        self.results = results
    }

    init(
        builderClosure: ExtrinsicBuilderIndexedClosure?,
        error: Error,
        indexes: [Int]
    ) {
        self.builderClosure = builderClosure
        results = indexes.map { .init(index: $0, result: .failure(error)) }
    }

    func failedIndexes() -> IndexSet {
        let indexList: [Int] = results.compactMap { indexedResult in
            switch indexedResult.result {
            case .success:
                return nil
            case .failure:
                return indexedResult.index
            }
        }

        return IndexSet(indexList)
    }

    func errors() -> [Error] {
        let errors: [Error] = results.compactMap { indexedResult in
            switch indexedResult.result {
            case .success:
                return nil
            case let .failure(error):
                return error
            }
        }

        return errors
    }
}

typealias FeeExtrinsicResult = Result<RuntimeDispatchInfo, Error>
typealias FeeIndexedExtrinsicResult = ExtrinsicRetriableResult<RuntimeDispatchInfo>

typealias EstimateFeeClosure = (FeeExtrinsicResult) -> Void
typealias EstimateFeeIndexedClosure = (FeeIndexedExtrinsicResult) -> Void

typealias SubmitExtrinsicResult = Result<String, Error>
typealias SubmitIndexedExtrinsicResult = ExtrinsicRetriableResult<String>

typealias ExtrinsicSubmitClosure = (SubmitExtrinsicResult) -> Void
typealias ExtrinsicSubmitIndexedClosure = (SubmitIndexedExtrinsicResult) -> Void

typealias ExtrinsicSubscriptionIdClosure = (UInt16) -> Bool
typealias ExtrinsicSubscriptionStatusClosure = (Result<ExtrinsicStatus, Error>) -> Void

typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias ExtrinsicBuilderIndexedClosure = (ExtrinsicBuilderProtocol, Int) throws -> (ExtrinsicBuilderProtocol)
