import Foundation
@testable import novawallet

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
        chain: ChainModel
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }
}
