import Foundation
import Foundation_iOS

final class SubtensorSubnetDetailsPresenter {
    weak var view: SubtensorSubnetDetailsViewProtocol?
    weak var selectionDelegate: SubtensorSubnetSelectDelegate?

    let model: SubtensorSubnetSelectViewModel
    let interactor: SubnetDetailsInteractorInputProtocol
    let wireframe: SubtensorSubnetDetailsWireframeProtocol
    let earnSettings: SubtensorEarnSettingsProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol
    private var cachedRisk: SubtensorRankedSubnet?

    init(
        model: SubtensorSubnetSelectViewModel,
        selectionDelegate: SubtensorSubnetSelectDelegate,
        interactor: SubnetDetailsInteractorInputProtocol,
        wireframe: SubtensorSubnetDetailsWireframeProtocol,
        earnSettings: SubtensorEarnSettingsProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.model = model
        self.selectionDelegate = selectionDelegate
        self.interactor = interactor
        self.wireframe = wireframe
        self.earnSettings = earnSettings
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

extension SubtensorSubnetDetailsPresenter: SubtensorSubnetDetailsPresenterProtocol {
    func setup() {
        let strings = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable
        let subtitle = model.target.isRoot ? strings.stakingSubtensorUiRewardsTao() : model.subtitle
        view?.didReceive(title: model.title, price: model.price, change: model.weeklyChangeText, subtitle: subtitle)
        view?.didReceiveFavorite(model.subnetRef.map { Set(earnSettings.favouriteSubnets).contains($0) } ?? false)

        if let subnetRef = model.subnetRef {
            view?.didReceive(history: nil)
            interactor.loadHistory(for: subnetRef, period: .week)
            interactor.loadRisk(for: subnetRef.netuid)
        } else {
            view?.didReceive(history: .notListed)
            view?.didReceive(risk: nil)
        }
    }

    func selectPeriod(_ period: SubtensorPricePeriod) {
        guard let subnetRef = model.subnetRef else { return }
        view?.didReceive(history: nil)
        interactor.loadHistory(for: subnetRef, period: period)
    }

    func toggleFavorite() {
        guard let subnetRef = model.subnetRef else { return }
        var favorites = Set(earnSettings.favouriteSubnets)
        if !favorites.insert(subnetRef).inserted { favorites.remove(subnetRef) }
        earnSettings.favouriteSubnets = favorites.sorted { $0.netuid < $1.netuid }
        view?.didReceiveFavorite(favorites.contains(subnetRef))
    }

    func selectValidator() {
        guard let selectionDelegate else { return }
        wireframe.showValidators(from: view, target: model.target, delegate: selectionDelegate)
    }

    func continueStaking() {
        selectValidator()
    }
}

extension SubtensorSubnetDetailsPresenter: SubnetDetailsInteractorOutputProtocol {
    func didReceive(history: SubtensorPriceHistoryResult) {
        view?.didReceive(history: history)
    }

    func didReceive(risk: SubtensorRankedSubnet?) {
        cachedRisk = risk
        guard let risk, risk.isEligible else {
            view?.didReceive(risk: nil)
            return
        }

        let strings = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable
        let profile: String?
        switch risk.riskClass {
        case .stable: profile = strings.stakingSubtensorUiDetailProfileStable()
        case .balanced: profile = strings.stakingSubtensorUiDetailProfileBalanced()
        case .higherUpside: profile = strings.stakingSubtensorUiDetailProfileUpside()
        case .aboveThreshold: profile = strings.stakingSubtensorUiDetailProfileRisky()
        case .none: profile = nil
        }

        var lines = [profile].compactMap { $0 }
        if let ageBlocks = risk.ageBlocks {
            let durationSeconds = Double(ageBlocks) * Double(SubtensorStakingFlowConstants.blockTimeMillis) / 1000
            let secondsPerMonth = 60.0 * 60.0 * 24.0 * 30.0
            let months = Int(durationSeconds / secondsPerMonth)
            lines.append(strings.stakingSubtensorUiDetailAgeFormat(months))
        }
        lines.append(strings.stakingSubtensorUiDetailValidatorsFormat(risk.eligibleValidators))
        if let pool = risk.taoIn {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let amount = formatter.string(from: NSDecimalNumber(decimal: pool)) ?? pool.description
            lines.append(strings.stakingSubtensorUiDetailPoolFormat(amount))
        }
        view?.didReceive(risk: lines.joined(separator: "\n"))
    }

    func didFailHistory(_: Error) {
        view?.didReceive(history: .notListed)
    }
}

extension SubtensorSubnetDetailsPresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else { return }
        let strings = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable
        let subtitle = model.target.isRoot ? strings.stakingSubtensorUiRewardsTao() : model.subtitle
        view?.didReceive(title: model.title, price: model.price, change: model.weeklyChangeText, subtitle: subtitle)
        didReceive(risk: cachedRisk)
    }
}
