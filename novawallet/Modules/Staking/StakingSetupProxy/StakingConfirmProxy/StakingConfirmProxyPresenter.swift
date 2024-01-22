import Foundation
import SoraFoundation
import SubstrateSdk

final class StakingConfirmProxyPresenter: StakingProxyBasePresenter {
    weak var view: StakingConfirmProxyViewProtocol? {
        baseView as? StakingConfirmProxyViewProtocol
    }

    let wireframe: StakingConfirmProxyWireframeProtocol
    let interactor: StakingConfirmProxyInteractorInputProtocol
    let proxyAddress: AccountAddress
    let wallet: MetaAccountModel
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let validationsFactory: ProxyConfirmValidationsFactoryProtocol

    private lazy var walletIconGenerator = NovaIconGenerator()

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        proxyAddress: AccountAddress,
        interactor: StakingConfirmProxyInteractorInputProtocol,
        wireframe: StakingConfirmProxyWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: ProxyDataValidatorFactoryProtocol,
        validationsFactory: ProxyConfirmValidationsFactoryProtocol,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.proxyAddress = proxyAddress
        self.wallet = wallet
        self.interactor = interactor
        self.wireframe = wireframe
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.validationsFactory = validationsFactory

        super.init(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager
        )
    }

    override func setup() {
        super.setup()

        provideProxyDeposit()
        provideNetworkViewModel()
        provideProxiedWalletViewModel()
        provideProxiedAddressViewModel()
        provideProxyAddressViewModel()
    }

    private func provideNetworkViewModel() {
        let viewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        view?.didReceiveNetwork(viewModel: viewModel)
    }

    private func provideProxiedWalletViewModel() {
        let name = wallet.name

        let icon = wallet.walletIdenticonData().flatMap { try? walletIconGenerator.generateFromAccountId($0) }
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }
        let viewModel = StackCellViewModel(details: name, imageViewModel: iconViewModel)
        view?.didReceiveWallet(viewModel: viewModel)
    }

    private func provideProxiedAddressViewModel() {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        let displayAddress = DisplayAddress(address: address, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveProxiedAddress(viewModel: viewModel)
    }

    private func provideProxyAddressViewModel() {
        let displayAddress = DisplayAddress(address: proxyAddress, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveProxyAddress(viewModel: viewModel)
    }

    override func getProxyAddress() -> AccountAddress {
        proxyAddress
    }

    override func createValidations() -> [DataValidating] {
        let args = ConfirmProxyValidationArgs(
            proxyAddress: getProxyAddress(),
            chainAsset: chainAsset,
            proxy: proxy,
            limitProxyCount: maxProxies,
            feeFetchClosure: { [weak self] in self?.interactor.estimateFee() },
            assetBalance: assetBalance,
            proxyDeposit: proxyDeposit,
            existensialDeposit: existensialDeposit,
            fee: fee
        )

        return validationsFactory.validations(args, locale: selectedLocale)
    }
}

extension StakingConfirmProxyPresenter: StakingConfirmProxyPresenterProtocol {
    func showProxiedAddressOptions() {
        guard let view = view else {
            return
        }
        wireframe.presentAccountOptions(
            from: view,
            address: "",
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func showProxyAddressOptions() {
        guard let view = view else {
            return
        }
        wireframe.presentAccountOptions(
            from: view,
            address: proxyAddress,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func confirm() {
        view?.didStartLoading()
        let validations = createValidations()

        DataValidationRunner(validators: validations).runValidation { [weak self] in
            self?.interactor.submit()
        }
    }
}

extension StakingConfirmProxyPresenter: StakingConfirmProxyInteractorOutputProtocol {
    func didSubmit() {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: view,
            completionAction: .dismiss,
            locale: selectedLocale
        )
    }

    func didReceive(error: StakingConfirmProxyError) {
        view?.didStopLoading()

        switch error {
        case let .submit(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension StakingConfirmProxyPresenter: StakingRemoveProxyInteractorOutputProtocol {
    func didReceive(removingError: StakingRemoveProxyError) {
        switch removingError {
        case let .handleProxies(error):
            didReceive(baseError: .handleProxies(error))
        case let .balance(error):
            didReceive(baseError: .balance(error))
        case let .price(error):
            didReceive(baseError: .price(error))
        case let .fee(error):
            didReceive(baseError: .fee(error))
        case let .submit(error):
            didReceive(error: .submit(error))
        }
    }
}
