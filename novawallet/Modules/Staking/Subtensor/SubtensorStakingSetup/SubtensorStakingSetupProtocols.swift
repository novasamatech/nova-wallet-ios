import Foundation

protocol SubtensorStakingSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceive(viewModel: SubtensorStakingSetupViewModel)
}

protocol SubtensorStakingSetupPresenterProtocol: AnyObject {
    func setup()
    func updateAmount(_ newValue: Decimal?)
    func selectMax()
    func selectAmountPercentage(_ percentage: Float)
    func selectValidator()
    func selectCardHeader()
    func chooseMyself()
    func selectSettings()
    func showSwapRateInfo()
    func showAvgBuyPriceInfo()
    func getTao()
    func proceed()
}

protocol SubtensorSetupInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func cachedRankingView() -> HTTPCachePeek<SubtensorRankedSubnets>
    func cachedYields(netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields>
    func cachedRootYield() -> HTTPCachePeek<SubtensorReportedYield?>
    func presetValidator(on subnet: SubtensorSubnetRef, existingHotkey: AccountId?)
    func loadLockedValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadRootYield()
    func loadSubnet(netuid: UInt16)
    func loadCatalogue()
    func loadYields(netuid: UInt16)
    func loadRankingView()
    func loadSubnetLogos()
    func loadCostBasis(for netuid: UInt16)
    func saveSlippage(_ tolerance: BigRational)
}

protocol SubtensorSetupInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef)
    func didReceiveRootYield(_ yield: SubtensorReportedYield?)
    func didReceiveSubnet(_ target: SubtensorStakeTarget)
    func didFailSubnet(_ error: Error)
    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?)
    func didReceiveYields(_ yields: SubtensorAlphaYields?, netuid: UInt16)
    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?)
    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?)
}

protocol SubtensorStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, SubtensorStakingErrorPresentable, SubtensorGetTaoRouting, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable {
    func showConfirmation(
        from view: SubtensorStakingSetupViewProtocol?,
        model: SubtensorStakingConfirmModel
    )

    func showValidatorSelection(
        from view: SubtensorStakingSetupViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    )

    func showSubnetSelection(
        from view: SubtensorStakingSetupViewProtocol?,
        delegate: SubtensorSubnetSelectDelegate
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
