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
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending]
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }
    
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending]
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }
    
    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicSignedExtending],
        customFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }
    
    func createExtrinsicSubmissionMonitor(
        with extrinsicService: ExtrinsicServiceProtocol
    ) -> ExtrinsicSubmitMonitorFactoryProtocol {
        fatalError("Unsupported factory method")
    }
}
