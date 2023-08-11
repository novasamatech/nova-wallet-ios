import BigInt

protocol StakingTypeViewProtocol: ControllerBackedProtocol {
    func didReceivePoolBanner(viewModel: PoolStakingTypeViewModel, available: Bool)
    func didReceiveDirectStakingBanner(viewModel: DirectStakingTypeViewModel, available: Bool)
    func didReceive(stakingTypeSelection: StakingTypeSelection)
    func didReceiveSaveChangesState(available: Bool)
}

protocol StakingTypePresenterProtocol: AnyObject {
    func setup()
    func selectValidators()
    func selectNominationPool()
    func change(stakingTypeSelection: StakingTypeSelection)
    func save()
    func back()
}

protocol StakingTypeInteractorInputProtocol: AnyObject {
    func setup()
    func change(stakingTypeSelection: StakingTypeSelection)
}

protocol StakingTypeInteractorOutputProtocol: AnyObject {
    func didReceive(nominationPoolRestrictions: RelaychainStakingRestrictions)
    func didReceive(directStakingRestrictions: RelaychainStakingRestrictions)
    func didReceive(method: StakingSelectionMethod)
    func didReceive(error: StakingTypeError)
}

protocol StakingTypeWireframeProtocol: AlertPresentable, CommonRetryable {
    func complete(from view: ControllerBackedProtocol?)
    func showNominationPoolsList(
        from view: ControllerBackedProtocol?,
        amount: BigUInt,
        delegate: StakingSelectPoolDelegate?,
        selectedPool: NominationPools.SelectedPool?
    )
}

enum StakingTypeError: Error {
    case restrictions(Error)
    case recommendation(Error)
}
