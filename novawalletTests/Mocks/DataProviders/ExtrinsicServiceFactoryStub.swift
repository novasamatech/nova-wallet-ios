import Foundation
@testable import novawallet
import SubstrateSdk

final class ExtrinsicServiceFactoryStub: ExtrinsicServiceFactoryProtocol {
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol = ExtrinsicOperationFactoryStub()
    ) {
        self.extrinsicService = extrinsicService
        self.extrinsicOperationFactory = extrinsicOperationFactory
    }

    func createService(
        account _: ChainAccountResponse,
        chain _: ChainModel,
        extensions _: [TransactionExtending]
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }

    func createService(
        account _: ChainAccountResponse,
        chain _: ChainModel,
        extensions _: [TransactionExtending],
        customFeeEstimatingFactory _: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }

    func createOperationFactory(
        account _: ChainAccountResponse,
        chain _: ChainModel,
        extensions _: [TransactionExtending]
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }

    func createOperationFactory(
        account _: ChainAccountResponse,
        chain _: ChainModel,
        extensions _: [TransactionExtending],
        customFeeEstimatingFactory _: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }

    func createExtrinsicSubmissionMonitor(
        with _: ExtrinsicServiceProtocol
    ) -> ExtrinsicSubmitMonitorFactoryProtocol {
        fatalError("Unsupported factory method")
    }
}
