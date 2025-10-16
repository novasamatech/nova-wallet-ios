import Foundation
@testable import novawallet
import SubstrateSdk

final class ExtrinsicServiceFactoryStub: ExtrinsicServiceFactoryProtocol {
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    let extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol

    init(
        extrinsicService: ExtrinsicServiceProtocol = ExtrinsicServiceStub.dummy(),
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol = ExtrinsicOperationFactoryStub(),
        extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol = ExtrinsicSubmitMonitorFactoryStub.dummy()
    ) {
        self.extrinsicService = extrinsicService
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.extrinsicMonitorFactory = extrinsicMonitorFactory
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
        extrinsicMonitorFactory
    }
}
