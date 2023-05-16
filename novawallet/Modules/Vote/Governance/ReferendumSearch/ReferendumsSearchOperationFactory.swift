import RobinHood

typealias ReferendumsSearchOperationClosure = (String) -> BaseOperation<[ReferendumsCellViewModel]>

protocol ReferendumsSearchOperationFactoryProtocol {
    func createOperationClosure(cells: [ReferendumsCellViewModel]) -> ReferendumsSearchOperationClosure
}

final class ReferendumsSearchOperationFactory: ReferendumsSearchOperationFactoryProtocol {
    func createOperationClosure(cells: [ReferendumsCellViewModel]) -> ReferendumsSearchOperationClosure {
        ReferendumsSearchManager(cells: cells).searchOperation
    }
}
