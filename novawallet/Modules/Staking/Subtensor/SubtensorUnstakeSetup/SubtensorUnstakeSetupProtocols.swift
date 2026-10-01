import Foundation

protocol SubtensorUnstakeSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountAsset(viewModel: AssetViewModel)
    func didReceive(viewModel: SubtensorUnstakeSetupViewModel)
}

protocol SubtensorUnstakeSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectMax()
    func selectAmountPercentage(_ percentage: Float)
    func showValidatorInfo()
    func showSwapRateInfo()
    func showAvgBuyPriceInfo()
    func proceed()
}

protocol SubtensorUnstakeInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func loadSubnetsInfo(forcingRefresh: Bool)
    func loadCatalogue(forcingRefresh: Bool)
    func loadSubnetLogos()
    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadRootHolds(for hotkeys: [AccountId])
    func loadCostBasis(for netuid: UInt16)
}

protocol SubtensorUnstakeInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo)
    func didReceiveSubnetsInfoError(_ error: Error)
    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?)
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, hotkey: AccountId)
    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold])
    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?)
}

protocol SubtensorUnstakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, SubtensorStakingErrorPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable {
    func showConfirm(
        from view: SubtensorUnstakeSetupViewProtocol?,
        model: SubtensorUnstakeConfirmModel
    )
}
