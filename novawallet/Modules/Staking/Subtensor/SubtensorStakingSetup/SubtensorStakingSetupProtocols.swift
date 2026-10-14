import Foundation

protocol SubtensorStakingSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceive(viewModel: SubtensorStakingSetupViewModel)
}

protocol SubtensorStakingSetupPresenterProtocol: AnyObject {
    func showAllSubnets()
    func retryQuickPick()
    func setup()
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

protocol SubtensorSetupInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func loadQuickPickSnapshot(generation: Int)
    func cancelQuickPickSnapshot()
    func cachedRankingView() -> HTTPCachePeek<SubtensorRankedSubnets>
    func cachedYields(netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields>
    func presetValidator(on subnet: SubtensorSubnetRef, existingHotkey: AccountId?)
    func loadLockedValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadSubnet(netuid: UInt16)
    func loadYields(netuid: UInt16)
    func loadRankingView()
    func saveSlippage(_ tolerance: BigRational)
}

protocol SubtensorSetupInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveQuickPickSnapshot(
        _ result: Result<(SubtensorSubnetCatalogue, SubtensorSubnetsInfo), Error>,
        generation: Int
    )
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef)
    func didReceiveSubnet(_ target: SubtensorStakeTarget)
    func didFailSubnet(_ error: Error)
    func didReceiveYields(_ yields: SubtensorAlphaYields?, netuid: UInt16)
    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?)
}

protocol SubtensorStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, SubtensorStakingErrorPresentable, GetTokenOptionsPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable {
    func showAllSubnets(
        from view: SubtensorStakingSetupViewProtocol?,
        browseState: SubtensorSubnetBrowseState,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showConfirmation(
        from view: SubtensorStakingSetupViewProtocol?,
        model: SubtensorConfirmModel
    )

    func showValidatorSelection(
        from view: SubtensorStakingSetupViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    )

    func showSubnetDetails(
        from view: SubtensorStakingSetupViewProtocol?,
        input: SubtensorSubnetDetailsInput,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showSlippageSettings(
        from view: SubtensorStakingSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    )

    func popTopControllers(
        from view: SubtensorStakingSetupViewProtocol?,
        completion: @escaping () -> Void
    )
}
