import Foundation

protocol SubtensorUnstakeSetupViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountAsset(viewModel: AssetViewModel)
    func didReceive(viewModel: SubtensorUnstakeSetupViewModel)
}

protocol SubtensorUnstakeSetupPresenterProtocol: AnyObject {
    func setup()
    func didAppear()
    func updateAmount(_ newValue: Decimal?)
    func selectMax()
    func selectAmountPercentage(_ percentage: Float)
    func selectValidator()
    func showSwapRateInfo()
    func showAvgBuyPriceInfo()
    func proceed()
}

protocol SubtensorUnstakeSetupInteractorInputProtocol: SubtensorBaseInteractorInputProtocol {
    func loadSubnetsInfo(for netuid: UInt16)
    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadValidators(_ hotkeys: [AccountId], on subnet: SubtensorSubnetRef)
    func loadGroupHotkeys(_ hotkeys: [AccountId], netuid: UInt16)
}

protocol SubtensorUnstakeSetupInteractorOutputProtocol: SubtensorBaseInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo)
    func didReceiveSubnetsInfoError(_ error: Error)
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, hotkey: AccountId)
    func didReceiveValidators(_ validators: [AccountId: SubtensorValidatorDirectoryItem], hotkeys: [AccountId])
    func didFailValidators(for hotkeys: [AccountId])
    func didReceiveGroupHotkeys(_ info: [AccountId: SubtensorGroupHotkeyInfo])
}
