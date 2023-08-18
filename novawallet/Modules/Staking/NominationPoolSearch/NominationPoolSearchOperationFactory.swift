import RobinHood

typealias NominationPoolSearchOperationClosure = (String) -> BaseOperation<[StakingSelectPoolViewModel]>

protocol NominationPoolSearchOperationFactoryProtocol {
    func createOperationClosure(viewModels: [StakingSelectPoolViewModel]) -> NominationPoolSearchOperationClosure
}

final class NominationPoolSearchOperationFactory: NominationPoolSearchOperationFactoryProtocol {
    func createOperationClosure(viewModels: [StakingSelectPoolViewModel]) -> NominationPoolSearchOperationClosure {
        NominationPoolSearchManager(viewModels: viewModels).searchOperation
    }
}
