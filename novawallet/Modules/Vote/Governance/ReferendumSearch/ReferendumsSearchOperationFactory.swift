import RobinHood

typealias ReferendumsSearchOperation = (String) -> BaseOperation<[ReferendumsCellViewModel]>

protocol ReferendumsSearchOperationFactoryProtocol {
    func createOperation(cells: [ReferendumsCellViewModel]) -> ReferendumsSearchOperation
}

final class ReferendumsSearchOperationFactory: ReferendumsSearchOperationFactoryProtocol {
    func createOperation(cells: [ReferendumsCellViewModel]) -> ReferendumsSearchOperation {
        ReferendumsSearchManager(cells: cells).searchOperation
    }
}
