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
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [TransactionExtending]
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }
    
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [TransactionExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [TransactionExtending]
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }
    
    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [TransactionExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }
    
    func createExtrinsicSubmissionMonitor(
        with extrinsicService: ExtrinsicServiceProtocol
    ) -> ExtrinsicSubmitMonitorFactoryProtocol {
        extrinsicMonitorFactory
    }
}
