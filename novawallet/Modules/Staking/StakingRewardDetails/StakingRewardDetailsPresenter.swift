import Foundation
import IrohaCrypto
import SubstrateSdk
import SoraFoundation

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let input: StakingRewardDetailsInput
    private let viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol
    private let explorers: [ChainModel.Explorer]?
    private let chainFormat: ChainFormat
    private var priceData: PriceData?

    init(
        input: StakingRewardDetailsInput,
        viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol,
        explorers: [ChainModel.Explorer]?,
        chainFormat: ChainFormat,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.input = input
        self.viewModelFactory = viewModelFactory
        self.explorers = explorers
        self.chainFormat = chainFormat
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let viewModel = try? viewModelFactory.createViewModel(
            input: input,
            priceData: priceData,
            locale: selectedLocale
        ) else {
            return
        }

        view?.didReceive(amountViewModel: viewModel.amount)
        view?.didReceive(validatorViewModel: viewModel.validator)
        view?.didReceive(eraViewModel: viewModel.era)
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

    func handleValidatorAccountAction() {
        guard
            let view = view,
            let address = try? input.payoutInfo.validator.toAddress(using: chainFormat)
        else { return }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: explorers,
            locale: selectedLocale
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

extension StakingRewardDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
