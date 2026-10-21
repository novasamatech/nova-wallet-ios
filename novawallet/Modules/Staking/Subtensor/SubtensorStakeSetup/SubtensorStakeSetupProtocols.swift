import Foundation
import NovaAnalytics

protocol SubtensorStakeSetupViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceive(viewModel: SubtensorStakeSetupViewModel)
}

protocol SubtensorStakeSetupPresenterProtocol: AnyObject {
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

protocol SubtensorStakeSetupInteractorInputProtocol: SubtensorBaseInteractorInputProtocol {
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

protocol SubtensorStakeSetupInteractorOutputProtocol: SubtensorBaseInteractorOutputProtocol {
    func didReceiveQuickPickSnapshot(_ result: Result<SubtensorQuickPickSnapshot, Error>)
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef)
    func didFailValidator(_ error: Error, on subnet: SubtensorSubnetRef)
    func didReceiveSubnet(_ target: SubtensorStakeTarget)
    func didFailSubnet(_ error: Error)
    func didReceiveYields(_ yields: SubtensorAlphaYields?, netuid: UInt16)
    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?)
    func didReceiveBlockTime(_ blockTime: BlockTime)
}

protocol SubtensorStakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, SubtensorErrorPresentable, GetTokenOptionsPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable, CollatorStakingDelegationSelectable {
    func showAllSubnets(
        from view: SubtensorStakeSetupViewProtocol?,
        browseState: SubtensorSubnetBrowseState,
        delegate: SubtensorSubnetSelectDelegate,
        source: SubnetListSource
    )

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        model: SubtensorConfirmModel
    )

    func showValidatorSelection(
        from view: SubtensorStakeSetupViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        analytics: SubtensorValidatorSelectAnalytics,
        delegate: SubtensorValidatorSelectDelegate
    )

    func showSubnetDetails(
        from view: SubtensorStakeSetupViewProtocol?,
        input: SubtensorSubnetDetailsInput,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showRootDetails(
        from view: SubtensorStakeSetupViewProtocol?,
        browseState: SubtensorSubnetBrowseState
    )

    func showSlippageSettings(
        from view: SubtensorStakeSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    )

    func popTopControllers(
        from view: SubtensorStakeSetupViewProtocol?,
        completion: @escaping () -> Void
    )
}
