import Operation_iOS

typealias NominationPoolSearchOperationClosure = (String) -> BaseOperation<[NominationPools.PoolStats]>

protocol NominationPoolSearchOperationFactoryProtocol {
    func createOperationClosure(stats: [NominationPools.PoolStats]) -> NominationPoolSearchOperationClosure
}

final class NominationPoolSearchOperationFactory: NominationPoolSearchOperationFactoryProtocol {
    func createOperationClosure(stats: [NominationPools.PoolStats]) -> NominationPoolSearchOperationClosure {
        NominationPoolSearchManager(stats: stats).searchOperation
    }
}
