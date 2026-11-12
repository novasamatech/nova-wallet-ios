import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class AssetExchangeOperationFailureTests: XCTestCase {
    func testFailedHopReportsSubmittedTxHash() {
        let submissionWrapper = CompoundOperationWrapper.createWithResult(
            createSubmission(status: .failure(createFailedExtrinsic()))
        )

        let failure = executeHop(after: submissionWrapper)

        XCTAssertEqual(failure.stage, .submitted(txHash: Self.txHash))
        XCTAssertTrue(failure.error is DispatchCallError)
    }

    func testHopFailedBeforeSubmissionReportsNoTxHash() {
        let submissionWrapper = CompoundOperationWrapper<ExtrinsicMonitorSubmission>.createWithError(
            JSONRPCEngineError.clientCancelled
        )

        let failure = executeHop(after: submissionWrapper)

        XCTAssertEqual(failure.stage, .notSubmitted)
        XCTAssertNil(failure.submittedTxHash)
        XCTAssertEqual(failure.error as? JSONRPCEngineError, .clientCancelled)
    }
}

private extension AssetExchangeOperationFailureTests {
    static let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)
    static let blockHash = Data(repeating: 8, count: 32).toHex(includePrefix: true)

    func executeHop(
        after submissionWrapper: CompoundOperationWrapper<ExtrinsicMonitorSubmission>
    ) -> AssetExchangeOperationFailure {
        let measuringOperation = ClosureOperation<Balance> {
            let submission = try submissionWrapper.targetOperation.extractNoCancellableResultData()

            switch submission.status {
            case let .failure(failure):
                throw failure.error
            case .success:
                return 0
            }
        }

        measuringOperation.addDependency(submissionWrapper.targetOperation)

        let hopWrapper = submissionWrapper
            .insertingTail(operation: measuringOperation)
            .failingWithSubmissionStage { submissionWrapper.targetOperation.submittedTxHash }

        OperationQueue().addOperations(hopWrapper.allOperations, waitUntilFinished: true)

        do {
            _ = try hopWrapper.targetOperation.extractNoCancellableResultData()
            XCTFail("Expected the hop to fail")
            return AssetExchangeOperationFailure(stage: .notSubmitted, error: CommonError.undefined)
        } catch {
            return AssetExchangeOperationFailure(wrapping: error)
        }
    }

    func createFailedExtrinsic() -> SubstrateExtrinsicStatus.FailedExtrinsic {
        .init(
            extrinsicHash: Self.txHash,
            blockHash: Self.blockHash,
            error: .other(.init(module: "Router", reason: "TradingLimitReached"))
        )
    }

    func createSubmission(status: SubstrateExtrinsicStatus) -> ExtrinsicMonitorSubmission {
        let sender = AccountGenerator.generateSubstrateChainAccountResponse(for: KnowChainId.hydra)

        return ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: ExtrinsicSubmittedModel(txHash: Self.txHash, sender: .current(sender)),
            status: status
        )
    }
}
