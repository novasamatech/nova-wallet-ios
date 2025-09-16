import Foundation
import Foundation_iOS

final class CollatorStakingInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    let wireframe: CollatorStakingInfoWireframeProtocol
    let interactor: CollatorStakingInfoInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let viewModelFactory: CollatorStakingInfoViewModelFactoryProtocol
    let collatorInfo: CollatorStakingSelectionInfoProtocol
    let logger: LoggerProtocol

    private var price: PriceData?
    private var delegator: CollatorStakingDelegator?

    init(
        interactor: CollatorStakingInfoInteractorInputProtocol,
        wireframe: CollatorStakingInfoWireframeProtocol,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        collatorInfo: CollatorStakingSelectionInfoProtocol,
        viewModelFactory: CollatorStakingInfoViewModelFactoryProtocol,
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
                delegator: delegator,
                priceData: price,
                locale: selectedLocale
            )

            view?.didRecieve(state: .validatorInfo(viewModel))
        } catch {
            let errorDescription = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonErrorNoDataRetrieved()

            view?.didRecieve(state: .error(errorDescription))
        }
    }
}

extension CollatorStakingInfoPresenter: ValidatorInfoPresenterProtocol {
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
                chain: chain,
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

extension CollatorStakingInfoPresenter: CollatorStakingInfoInteractorOutputProtocol {
    func didReceivePrice(_ price: PriceData?) {
        self.price = price

        provideViewModel()
    }

    func didReceiveDelegator(_ delegator: CollatorStakingDelegator?) {
        self.delegator = delegator

        provideViewModel()
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        logger.error("Unexpected error: \(error)")
    }
}

extension CollatorStakingInfoPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}
