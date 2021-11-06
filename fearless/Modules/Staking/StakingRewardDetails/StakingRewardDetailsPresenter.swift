import Foundation
import IrohaCrypto
import SubstrateSdk

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let input: StakingRewardDetailsInput
    private let viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol
    private let explorers: [ChainModel.Explorer]?
    private var priceData: PriceData?

    init(
        input: StakingRewardDetailsInput,
        viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol,
        explorers: [ChainModel.Explorer]?
    ) {
        self.input = input
        self.viewModelFactory = viewModelFactory
        self.explorers = explorers
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(input: input, priceData: priceData)
        view?.reload(with: viewModel)
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view, payoutInfo: input.payoutInfo)
    }

    func handleValidatorAccountAction(locale: Locale) {
        guard
            let view = view,
            let address = viewModelFactory.validatorAddress(
                from: input.payoutInfo.validator
            )
        else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: explorers,
            locale: locale
        )
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsInteractorOutputProtocol {
    func didReceive(priceResult: Result<PriceData?, Error>) {
        switch priceResult {
        case let .success(priceData):
            self.priceData = priceData
            updateView()
        case .failure:
            priceData = nil
            updateView()
        }
    }
}
