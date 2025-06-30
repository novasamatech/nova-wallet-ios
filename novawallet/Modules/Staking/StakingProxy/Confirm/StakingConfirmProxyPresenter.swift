import Foundation
import Foundation_iOS
import SubstrateSdk

final class StakingConfirmProxyPresenter: StakingProxyBasePresenter {
    weak var view: StakingConfirmProxyViewProtocol? {
        baseView as? StakingConfirmProxyViewProtocol
    }

    let wireframe: StakingConfirmProxyWireframeProtocol
    let interactor: StakingConfirmProxyInteractorInputProtocol
    let proxyAddress: AccountAddress
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    private lazy var walletIconGenerator = NovaIconGenerator()

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        proxyAddress: AccountAddress,
        interactor: StakingConfirmProxyInteractorInputProtocol,
        wireframe: StakingConfirmProxyWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: ProxyDataValidatorFactoryProtocol,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.proxyAddress = proxyAddress
        self.interactor = interactor
        self.wireframe = wireframe
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory

        super.init(
            wallet: wallet,
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

        provideTitles()
        provideProxyTypeViewModel()
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

    private func provideProxyTypeViewModel() {
        let type = R.string.localizable.stakingConfirmProxyTypeSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceiveProxyType(viewModel: type)
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

    private func provideTitles() {
        let typeTitle = R.string.localizable.stakingConfirmProxyTypeTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        let proxyAddressTitle = R.string.localizable.stakingConfirmProxyAccountProxy(
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceiveProxyType(title: typeTitle)
        view?.didReceiveProxyAddress(title: proxyAddressTitle)
    }

    override func getProxyAddress() -> AccountAddress {
        proxyAddress
    }

    override func updateView() {
        super.updateView()
        provideTitles()
    }
}

extension StakingConfirmProxyPresenter: StakingConfirmProxyPresenterProtocol {
    func showProxiedAddressOptions() {
        guard let view = view else {
            return
        }
        guard let address = try? wallet.address(for: chainAsset.chain) else {
            return
        }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
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
