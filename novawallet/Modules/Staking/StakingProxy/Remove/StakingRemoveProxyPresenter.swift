import Foundation
import Foundation_iOS
import SubstrateSdk

final class StakingRemoveProxyPresenter {
    weak var view: StakingConfirmProxyViewProtocol?

    let wireframe: StakingConfirmProxyWireframeProtocol
    let interactor: StakingRemoveProxyInteractorInputProtocol
    let proxyAccount: ProxyAccount
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let dataValidatingFactory: ProxyDataValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private var assetBalance: AssetBalance?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?

    private lazy var walletIconGenerator = NovaIconGenerator()
    private var proxyAddress: AccountAddress? {
        try? proxyAccount.accountId.toAddress(using: chainAsset.chain.chainFormat)
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        proxyAccount: ProxyAccount,
        interactor: StakingRemoveProxyInteractorInputProtocol,
        wireframe: StakingConfirmProxyWireframeProtocol,
        dataValidatingFactory: ProxyDataValidatorFactoryProtocol,
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.proxyAccount = proxyAccount
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
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
        guard let address = try? wallet.address(for: chainAsset.chain) else {
            return
        }

        let displayAddress = DisplayAddress(address: address, username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveProxiedAddress(viewModel: viewModel)
    }

    private func provideProxyAddressViewModel() {
        let displayAddress = DisplayAddress(address: proxyAddress ?? "", username: "")
        let viewModel = displayAddressViewModelFactory.createViewModel(from: displayAddress)
        view?.didReceiveProxyAddress(viewModel: viewModel)
    }

    private func provideFee() {
        guard let fee = fee?.amount.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveFee(viewModel: nil)
            return
        }
        let feeViewModel = balanceViewModelFactory.balanceFromPrice(
            fee,
            priceData: priceData
        ).value(for: selectedLocale)
        view?.didReceiveFee(viewModel: feeViewModel)
    }

    private func provideProxyTypeViewModel() {
        let type = R.string.localizable.stakingConfirmProxyTypeSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.didReceiveProxyType(viewModel: type)
    }

    private func createValidations() -> [DataValidating] {
        [
            dataValidatingFactory.validAddress(
                proxyAddress ?? "",
                chain: chainAsset.chain,
                locale: selectedLocale
            ),
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in
                    self?.interactor.estimateFee()
                }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: assetBalance?.regularTransferrableBalance(),
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]
    }

    private func provideTitles() {
        let typeTitle = R.string.localizable.stakingProxyRevokeAccessType(
            preferredLanguages: selectedLocale.rLanguages
        )
        let proxyAddressTitle = R.string.localizable.stakingProxyRevokeAccessProxyAddress(
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceiveProxyType(title: typeTitle)
        view?.didReceiveProxyAddress(title: proxyAddressTitle)
    }

    private func updateView() {
        provideProxyTypeViewModel()
        provideNetworkViewModel()
        provideProxiedWalletViewModel()
        provideProxiedAddressViewModel()
        provideProxyAddressViewModel()
        provideTitles()

        view?.didReceiveProxyDeposit(viewModel: nil)
    }
}

extension StakingRemoveProxyPresenter: StakingConfirmProxyPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

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
        guard let view = view, let proxyAddress = proxyAddress else {
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

    func showDepositInfo() {}
}

extension StakingRemoveProxyPresenter: StakingRemoveProxyInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        priceData = price
        provideFee()
    }

    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceive(fee: ExtrinsicFeeProtocol?) {
        self.fee = fee
        provideFee()
    }

    func didSubmit() {
        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: view,
            completionAction: .dismiss,
            locale: selectedLocale
        )
    }

    func didReceive(error: StakingRemoveProxyError) {
        view?.didStopLoading()

        switch error {
        case .balance, .price:
            interactor.remakeSubscriptions()
        case .fee:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.estimateFee()
            }
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

extension StakingRemoveProxyPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
