import Foundation

protocol SubtensorSetupViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceive(viewModel: SubtensorSetupViewModel)
}

protocol SubtensorSetupPresenterProtocol: AnyObject {
    func showAllSubnets()
    func retry()
    func setup()
    func didAppear()
    func updateAmount(_ newValue: Decimal?)
    func selectMax()
    func selectAmountPercentage(_ percentage: Float)
    func selectValidator()
    func selectCardHeader()
    func selectSettings()
    func showSwapRateInfo()
    func showAvgBuyPriceInfo()
    func getTao()
    func proceed()
}

protocol SubtensorSetupInteractorInputProtocol: SubtensorBaseInteractorInputProtocol {
    func loadQuickPickSnapshot(for order: SubtensorQuickPickOrder, selectedRef: SubtensorSubnetRef?)
    func cancelQuickPickSnapshot()
    func loadBlockTime()
    func presetValidator(on subnet: SubtensorSubnetRef, existingHotkey: AccountId?)
    func loadLockedValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadSubnet(netuid: UInt16)
    func loadYields(netuid: UInt16)
    func loadRankingView()
    func saveSlippage(_ tolerance: BigRational)
}

protocol SubtensorSetupInteractorOutputProtocol: SubtensorBaseInteractorOutputProtocol {
    func didReceiveQuickPickSnapshot(_ result: Result<SubtensorQuickPickSnapshot, Error>)
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef)
    func didFailValidator(_ error: Error, on subnet: SubtensorSubnetRef)
    func didReceiveSubnet(_ target: SubtensorStakeTarget)
    func didFailSubnet(_ error: Error)
    func didReceiveYields(_ yields: SubtensorAlphaYields?, netuid: UInt16)
    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?)
    func didReceiveBlockTime(_ blockTime: BlockTime)
}

protocol SubtensorSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, SubtensorErrorPresentable, GetTokenOptionsPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable {
    func showAllSubnets(
        from view: SubtensorSetupViewProtocol?,
        browseState: SubtensorSubnetBrowseState,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        model: SubtensorConfirmModel
    )

    func showValidatorSelection(
        from view: SubtensorSetupViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    )

    func showSubnetDetails(
        from view: SubtensorSetupViewProtocol?,
        input: SubtensorSubnetDetailsInput,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showRootDetails(
        from view: SubtensorSetupViewProtocol?,
        browseState: SubtensorSubnetBrowseState
    )

    func showSlippageSettings(
        from view: SubtensorSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    )

    func popTopControllers(
        from view: SubtensorSetupViewProtocol?,
        completion: @escaping () -> Void
    )
}
