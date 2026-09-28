import Foundation
import Foundation_iOS
import SubstrateSdk

final class SubtensorPositionPresenter {
    weak var view: SubtensorPositionViewProtocol?

    let interactor: SubtensorPositionInteractorInputProtocol
    let wireframe: SubtensorPositionWireframeProtocol
    let commonData: SubtensorStakingCommonData
    let precision: Int16
    let localizationManager: LocalizationManagerProtocol

    private var group: SubtensorPortfolioGroup

    init(
        group: SubtensorPortfolioGroup,
        commonData: SubtensorStakingCommonData,
        interactor: SubtensorPositionInteractorInputProtocol,
        wireframe: SubtensorPositionWireframeProtocol,
        precision: Int16,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.group = group
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
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? value.description
    }

    private func amount(_ value: Balance) -> Decimal {
        Decimal.fromSubstrateAmount(value, precision: precision) ?? 0
    }

    private func provideContent() {
        let strings = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable
        let isRoot = group.netuid == SubtensorStakingPallet.rootNetuid
        let subnet = commonData.subnetsInfo?.subnets.first { $0.netuid == group.netuid }
        let name = subnet?.displayName
        let symbol = subnet?.displaySymbol
        let title = isRoot
            ? strings.stakingSubtensorUiRootStaking()
            : (name.flatMap { $0.isEmpty ? nil : $0 } ?? strings.stakingSubtensorUiSubnetFormat(Int(group.netuid)))
        let unit = isRoot ? "TAO" : (symbol.flatMap { $0.isEmpty ? nil : $0 } ?? "α")
        let alphaAmount = amount(group.totalAlpha)
        let taoWorth = group.taoValue.map(amount)
        let fiat = taoWorth.flatMap { worth in
            commonData.price?.decimalRate.map { format(worth * $0) }
        }
        let rewards = group.positions.reduce(Balance.zero) { total, position in
            total + (commonData.claimable?.redeemable(for: position.hotkey) ?? 0)
        }
        let identity = commonData.delegates?
            .first { $0.info.delegateSs58 == group.primaryHotkey }?
            .identity?.displayName
        let gate = commonData.account.map { SubtensorOperationGate.verdict(for: $0.chainAccount.type) }
        let canOperate: Bool
        if case .allowed = gate { canOperate = true } else { canOperate = false }

        view?.didReceive(viewModel: SubtensorPositionViewModel(
            title: title,
            amount: "\(format(alphaAmount)) \(unit)",
            fiat: fiat,
            rewardTitle: isRoot
                ? strings.stakingSubtensorUiPositionRewards()
                : strings.stakingSubtensorUiPositionEstimatedRewards(),
            rewardValue: isRoot ? "\(format(amount(rewards))) TAO" : nil,
            worthNow: taoWorth.map { "≈ \(format($0)) TAO" },
            validator: identity ?? strings.stakingSubtensorUiPositionValidator(),
            isRoot: isRoot,
            canOperate: canOperate,
            hasRootHold: isRoot && (group.availability?.available ?? group.totalAlpha) < group.totalAlpha
        ))
    }
}

extension SubtensorPositionPresenter: SubtensorPositionPresenterProtocol {
    func setup() {
        provideContent()
        interactor.setup()
        selectPeriod(.week)
    }

    func selectPeriod(_ period: SubtensorPricePeriod) {
        guard group.netuid != SubtensorStakingPallet.rootNetuid,
              let subnet = commonData.subnetsInfo?.subnets.first(where: { $0.netuid == group.netuid }) else { return }
        view?.didReceive(history: nil)
        interactor.loadHistory(
            for: SubtensorSubnetRef(netuid: subnet.netuid, registeredAt: subnet.networkRegisteredAt),
            period: period
        )
    }

    func stakeMore() {
        guard let account = commonData.account,
              case .allowed = SubtensorOperationGate.verdict(for: account.chainAccount.type) else { return }
        wireframe.showStake(from: view, position: group.positions.first)
    }

    func unstake() {
        guard let account = commonData.account,
              case .allowed = SubtensorOperationGate.verdict(for: account.chainAccount.type) else { return }
        wireframe.showUnstake(from: view, position: group.positions.first)
    }

    func showValidatorInfo() {
        guard let delegate = commonData.delegates?.first(where: {
            $0.info.delegateSs58 == group.primaryHotkey
        }) else { return }
        wireframe.showValidatorInfo(from: view, delegate: delegate)
    }
}

extension SubtensorPositionPresenter: SubnetPositionInteractorOutputProtocol {
    func didReceive(group: SubtensorPortfolioGroup) {
        self.group = group
        provideContent()
    }

    func didReceive(history: SubtensorPriceHistoryResult) {
        view?.didReceive(history: history)
    }
}

extension SubtensorPositionPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true { provideContent() }
    }
}
