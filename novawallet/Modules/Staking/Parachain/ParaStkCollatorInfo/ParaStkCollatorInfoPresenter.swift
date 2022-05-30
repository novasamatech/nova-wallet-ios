import Foundation
import SoraFoundation

final class ParaStkCollatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    let wireframe: ParaStkCollatorInfoWireframeProtocol
    let interactor: ParaStkCollatorInfoInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let viewModelFactory: ParaStkCollatorInfoViewModelFactoryProtocol
    let collatorInfo: CollatorSelectionInfo
    let logger: LoggerProtocol

    private var price: PriceData?

    init(
        interactor: ParaStkCollatorInfoInteractorInputProtocol,
        wireframe: ParaStkCollatorInfoWireframeProtocol,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        collatorInfo: CollatorSelectionInfo,
        viewModelFactory: ParaStkCollatorInfoViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.collatorInfo = collatorInfo
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        do {
            let viewModel = try viewModelFactory.createViewModel(
                for: selectedAccount.chainAccount.accountId,
                collatorInfo: collatorInfo,
                priceData: price,
                locale: selectedLocale
            )

            view?.didRecieve(state: .validatorInfo(viewModel))
        } catch {
            let errorDescription = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )

            view?.didRecieve(state: .error(errorDescription))
        }
    }
}

extension ParaStkCollatorInfoPresenter: ValidatorInfoPresenterProtocol {
    func setup() {
        provideViewModel()

        interactor.setup()
    }

    func reload() {
        interactor.reload()
    }

    func presentAccountOptions() {
        if
            let view = view,
            let address = try? collatorInfo.accountId.toAddress(using: chain.chainFormat) {
            wireframe.presentAccountOptions(
                from: view,
                address: address,
                explorers: chain.explorers,
                locale: selectedLocale
            )
        }
    }

    func presentTotalStake() {
        let items = viewModelFactory.createStakingAmountsViewModel(
            from: collatorInfo,
            priceData: price
        )

        wireframe.showStakingAmounts(from: view, items: items)
    }

    func presentIdentityItem(_ value: ValidatorInfoViewModel.IdentityItemValue) {
        guard case let .link(value, tag) = value, let view = view else {
            return
        }

        wireframe.presentIdentityItem(
            from: view,
            tag: tag,
            value: value,
            locale: selectedLocale
        )
    }
}

extension ParaStkCollatorInfoPresenter: ParaStkCollatorInfoInteractorOutputProtocol {
    func didReceivePrice(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(price):
            self.price = price

            provideViewModel()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
            logger.error("Unexpected error: \(error)")
        }
    }
}

extension ParaStkCollatorInfoPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}
