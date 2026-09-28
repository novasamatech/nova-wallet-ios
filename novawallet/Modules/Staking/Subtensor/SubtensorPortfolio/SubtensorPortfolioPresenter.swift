import Foundation
import Foundation_iOS
import SubstrateSdk

final class SubtensorPortfolioPresenter {
    weak var view: SubtensorPortfolioViewProtocol?

    let interactor: SubnetPortfolioInteractorInputProtocol
    let wireframe: SubtensorPortfolioWireframeProtocol
    let commonData: SubtensorStakingCommonData
    let precision: Int16
    let localizationManager: LocalizationManagerProtocol

    private var state: Multistaking.SubtensorStakingState
    private var rows: [SubtensorPortfolioRowViewModel] = []
    private var period: SubtensorPricePeriod = .month
    private var syncFailed = false

    init(
        state: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData,
        interactor: SubnetPortfolioInteractorInputProtocol,
        wireframe: SubtensorPortfolioWireframeProtocol,
        precision: Int16,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.state = state
        self.commonData = commonData
        self.interactor = interactor
        self.wireframe = wireframe
        self.precision = precision
        self.localizationManager = localizationManager
    }

    private func format(_ value: Decimal, digits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? value.description
    }

    private func amount(_ value: Balance) -> Decimal {
        Decimal.fromSubstrateAmount(value, precision: precision) ?? 0
    }

    private func provideContent() {
        let strings = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable
        let portfolio = SubtensorPortfolioBuilder.build(state: state)
        let groups = [portfolio.root].compactMap { $0 } + portfolio.subnets
        rows = groups.map { group in
            let isRoot = group.netuid == SubtensorStakingPallet.rootNetuid
            let subnet = commonData.subnetsInfo?.subnets.first { $0.netuid == group.netuid }
            let subnetName = (subnet?.displayName).flatMap { $0.isEmpty ? nil : $0 }
            let subnetSymbol = (subnet?.displaySymbol).flatMap { $0.isEmpty ? nil : $0 }
            let title = isRoot
                ? strings.stakingSubtensorUiRootStaking()
                : (subnetName ?? strings.stakingSubtensorUiSubnetFormat(Int(group.netuid)))
            let symbol = isRoot ? "TAO" : (subnetSymbol ?? "α")
            let value = group.taoValue.map { "\(format(amount($0))) TAO" }
                ?? strings.stakingSubtensorUiPriceUnavailable()
            return SubtensorPortfolioRowViewModel(
                group: group,
                title: title,
                amount: "≈ \(format(amount(group.totalAlpha))) \(symbol)",
                value: value,
                subtitle: isRoot
                    ? strings.stakingSubtensorUiRewardsTao()
                    : strings.stakingSubtensorUiSubnetFormat(Int(group.netuid))
            )
        }

        let total = amount(portfolio.pricedTaoValue)
        let fiat = commonData.price?.decimalRate.map { format(total * $0) }
        view?.didReceive(viewModel: SubtensorPortfolioViewModel(
            total: "\(format(total)) TAO",
            fiat: fiat,
            rows: rows,
            syncFailed: syncFailed || commonData.positionsSyncFailed
        ))

        guard !groups.isEmpty else {
            view?.didReceive(series: nil)
            return
        }

        view?.didReceiveChartLoading()
        interactor.loadSeries(
            portfolio: portfolio,
            subnetsInfo: commonData.subnetsInfo,
            priceId: commonData.chainAsset?.asset.priceId,
            precision: precision,
            period: period
        )
    }
}

extension SubtensorPortfolioPresenter: SubtensorPortfolioPresenterProtocol {
    func setup() {
        provideContent()
        interactor.setup()
    }

    func selectPeriod(_ period: SubtensorPricePeriod) {
        self.period = period
        provideContent()
    }

    func selectPosition(at index: Int) {
        guard rows.indices.contains(index) else { return }
        wireframe.showPosition(from: view, group: rows[index].group, state: state, commonData: commonData)
    }

    func addPosition() {
        wireframe.showAddPosition(from: view)
    }

    func retry() {
        interactor.refresh()
    }
}

extension SubtensorPortfolioPresenter: SubnetPortfolioInteractorOutputProtocol {
    func didReceive(state: Multistaking.SubtensorStakingState) {
        self.state = state
        provideContent()
    }

    func didReceive(series: SubtensorPortfolioValueSeries?) {
        view?.didReceive(series: series)
    }

    func didReceiveSyncFailure(_ isFailed: Bool) {
        syncFailed = isFailed
        provideContent()
    }
}

extension SubtensorPortfolioPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true { provideContent() }
    }
}
