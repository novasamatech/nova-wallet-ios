import Foundation
import SoraFoundation
import BigInt

final class StakingNPoolsPresenter {
    weak var view: StakingMainViewProtocol?

    let interactor: StakingNPoolsInteractorInputProtocol
    let wireframe: StakingNPoolsWireframeProtocol
    let infoViewModelFactory: NetworkInfoViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol

    private var totalActiveStake: BigUInt?
    private var minStake: BigUInt?
    private var duration: StakingDuration?
    private var priceData: PriceData?

    init(
        interactor: StakingNPoolsInteractorInputProtocol,
        wireframe: StakingNPoolsWireframeProtocol,
        infoViewModelFactory: NetworkInfoViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.infoViewModelFactory = infoViewModelFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideStatics() {
        view?.didReceiveStatics(viewModel: StakingNominationPoolsStatics())
    }

    private func provideStakingInfo() {
        let params = NPoolsDetailsInfoParams(
            totalActiveStake: totalActiveStake,
            minStake: minStake,
            duration: duration
        )

        let viewModel = infoViewModelFactory.createNPoolsStakingInfoViewModel(
            for: params,
            chainAsset: chainAsset,
            priceData: priceData,
            locale: selectedLocale
        )

        view?.didRecieveNetworkStakingInfo(viewModel: viewModel)
    }

    private func updateView() {
        provideStatics()
        provideStakingInfo()
    }
}

extension StakingNPoolsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

    func performMainAction() {}

    func performRewardInfoAction() {}

    func performChangeValidatorsAction() {}

    func performSetupValidatorsForBondedAction() {}

    func performStakeMoreAction() {}

    func performRedeemAction() {}

    func performRebondAction() {}

    func performRebag() {}

    func performManageAction(_: StakingManageOption) {}

    func selectPeriod(_: StakingRewardFiltersPeriod) {}
}

extension StakingNPoolsPresenter: StakingNPoolsInteractorOutputProtocol {
    func didReceive(minStake: BigUInt?) {
        self.minStake = minStake

        provideStakingInfo()
    }

    func didReceive(duration: StakingDuration) {
        self.duration = duration

        provideStakingInfo()
    }

    func didReceive(totalActiveStake: BigUInt) {
        self.totalActiveStake = totalActiveStake

        provideStakingInfo()
    }

    func didReceive(price: PriceData?) {
        priceData = price

        provideStakingInfo()
    }

    func didReceive(error: StakingNPoolsError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .stateSetup:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .subscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .totalActiveStake:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryActiveStake()
            }
        case .stakingDuration:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryStakingDuration()
            }
        }
    }
}

extension StakingNPoolsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
