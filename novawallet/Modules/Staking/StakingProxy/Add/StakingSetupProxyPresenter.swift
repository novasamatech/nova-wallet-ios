import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

final class StakingSetupProxyPresenter: StakingProxyBasePresenter {
    weak var view: StakingSetupProxyViewProtocol? {
        baseView as? StakingSetupProxyViewProtocol
    }

    let wireframe: StakingSetupProxyWireframeProtocol
    let interactor: StakingSetupProxyInteractorInputProtocol
    let web3NameViewModelFactory: Web3NameViewModelFactoryProtocol
    private(set) var proxyAddress: StakingSetupProxyAccount? {
        didSet {
            guard view?.isSetup == true else {
                return
            }
            switch proxyAddress {
            case .none, .address:
                view?.didReceiveWeb3NameProxy(viewModel: .loaded(value: nil))
            case let .external(externalAccount):
                let isLoading = externalAccount.recipient.isLoading == true
                view?.didReceiveWeb3NameProxy(viewModel: isLoading ? .loading :
                    .loaded(value: externalAccount.recipient.value??.displayTitle))
            }
            provideAccountFieldStateViewModel()
        }
    }

    private var yourWallets: [MetaAccountChainResponse] = []
    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        interactor: StakingSetupProxyInteractorInputProtocol,
        wireframe: StakingSetupProxyWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: ProxyDataValidatorFactoryProtocol,
        web3NameViewModelFactory: Web3NameViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.web3NameViewModelFactory = web3NameViewModelFactory

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
        view?.didReceive(token: chainAsset.assetDisplayInfo.symbol)
        interactor.setup()
        provideInputViewModel()
    }

    private func showWeb3NameAddressList(recipients: [Web3TransferRecipient], for name: String) {
        guard let view = view else {
            return
        }

        let chain = chainAsset.chain
        view.didReceiveWeb3NameProxy(viewModel: .cached(value: nil))

        let viewModel = web3NameViewModelFactory.recipientListViewModel(
            recipients: recipients,
            for: name,
            chain: chain,
            selectedAddress: proxyAddress?.address
        )

        wireframe.presentWeb3NameAddressListPicker(from: view, viewModel: viewModel, delegate: self)
    }

    private func provideWeb3NameViewModel(_ authority: Web3TransferRecipient?, name: String) {
        guard let authority = authority else {
            if proxyAddress?.isExternal == true {
                proxyAddress = .external(.init(name: name, recipient: .loaded(value: nil)))
                view?.didReceiveProxyInputState(focused: true, empty: true)
            }
            return
        }

        let chain = chainAsset.chain

        if let account = authority.normalizedAddress(for: chain.chainFormat) {
            let authorityViewModel = StakingSetupProxyAccount.ExternalAccountValue(
                address: account,
                description: authority.description
            )
            proxyAddress = .external(.init(name: name, recipient: .loaded(value: authorityViewModel)))
            view?.didReceiveProxyInputState(focused: false, empty: nil)
        } else {
            proxyAddress = .external(.init(name: name, recipient: .loaded(value: nil)))
            didReceive(error: .web3Name(.invalidAddress(chain.name)))
        }
    }

    private func provideInputViewModel() {
        let value = proxyAddress?.address ?? ""

        let inputViewModel = InputViewModel.createAccountInputViewModel(for: value)

        view?.didReceiveProxyAccountInput(viewModel: inputViewModel)
    }

    private func updateRecepientAddress(_ newAddress: String) {
        guard proxyAddress?.address != newAddress else {
            return
        }

        proxyAddress = .address(newAddress)
    }

    func updateYourWalletsButton() {
        let isShowYourWallets = yourWallets.contains { $0.chainAccountResponse != nil }
        view?.didReceiveYourWallets(state: isShowYourWallets ? .inactive : .hidden)
    }

    private func proceedWithExternal(account: StakingSetupProxyAccount.ExternalAccount) {
        switch account.recipient {
        case let .cached(value), let .loaded(value):
            if value?.address == nil {
                didReceive(error: .web3Name(.accountNotFound(account.name)))
            } else {
                proceedWithValidation()
            }
        case .loading:
            // wait the result
            break
        }
    }

    private func proceedWithValidation() {
        let validations = createValidations()

        DataValidationRunner(validators: validations).runValidation { [weak self] in
            guard
                let address = self?.proxyAddress?.address else {
                return
            }

            self?.wireframe.showConfirmation(
                from: self?.view,
                proxyAddress: address
            )
        }
    }

    override func getProxyAddress() -> AccountAddress {
        proxyAddress?.address ?? ""
    }

    private func provideAccountFieldStateViewModel() {
        if
            let accountId = try? getProxyAddress().toAccountId(using: chainAsset.chain.chainFormat),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            let iconViewModel = DrawableIconViewModel(icon: icon)
            let viewModel = AccountFieldStateViewModel(icon: iconViewModel)
            view?.didReceiveAccountState(viewModel: viewModel)
        } else {
            let viewModel = AccountFieldStateViewModel(icon: nil)
            view?.didReceiveAccountState(viewModel: viewModel)
        }
    }
}

extension StakingSetupProxyPresenter: StakingSetupProxyPresenterProtocol {
    func complete(proxyInput: String) {
        guard !wireframe.checkDismissing(view: view) else {
            return
        }

        guard let web3Name = KiltW3n.web3Name(nameWithScheme: proxyInput) else {
            return
        }
        proxyAddress = .external(.init(
            name: KiltW3n.fullName(for: web3Name),
            recipient: .loading
        ))
        interactor.search(web3Name: web3Name)
    }

    func updateProxy(partialAddress: String) {
        if let w3n = KiltW3n.web3Name(nameWithScheme: partialAddress) {
            proxyAddress = .external(.init(
                name: KiltW3n.fullName(for: w3n),
                recipient: .cached(value: nil)
            ))
        } else {
            proxyAddress = .address(partialAddress)
        }

        view?.didReceiveWeb3NameProxy(viewModel: .loaded(value: nil))
    }

    func showWeb3NameProxy() {
        guard let view = view, let address = proxyAddress?.address else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func didTapOnYourWallets() {
        wireframe.showYourWallets(
            from: view,
            accounts: yourWallets,
            address: proxyAddress?.address,
            delegate: self
        )
    }

    func scanAddressCode() {
        wireframe.showAddressScan(from: view, delegate: self)
    }

    func proceed() {
        switch proxyAddress {
        case .none, .address:
            proceedWithValidation()
        case let .external(externalAccount):
            proceedWithExternal(account: externalAccount)
        }
    }
}

extension StakingSetupProxyPresenter: StakingSetupProxyInteractorOutputProtocol {
    func didReceive(error: StakingSetupProxyError) {
        switch error {
        case let .web3Name(error):
            wireframe.present(
                error: error,
                from: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.view?.didReceiveProxyInputState(focused: true, empty: nil)
                self?.proxyAddress = .external(.init(
                    name: self?.proxyAddress?.name ?? "",
                    recipient: .loaded(value: nil)
                ))
            }
        case .fetchMetaAccounts:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.refetchAccounts()
            }
        }
    }

    func didReceive(recipients: [Web3TransferRecipient], for name: String) {
        if recipients.count > 1 {
            showWeb3NameAddressList(recipients: recipients, for: name)
        } else {
            provideWeb3NameViewModel(recipients.first, name: name)
        }
    }

    func didReceive(yourWallets: [MetaAccountChainResponse]) {
        self.yourWallets = yourWallets
        updateYourWalletsButton()
    }
}

extension StakingSetupProxyPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        if let selectionState = context as? Web3NameAddressesSelectionState {
            let selectedAccount = selectionState.accounts[index]
            provideWeb3NameViewModel(selectedAccount, name: selectionState.name)
        }
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        view?.didReceiveProxyInputState(focused: true, empty: nil)
    }
}

extension StakingSetupProxyPresenter: YourWalletsDelegate {
    func yourWallets(
        selectionView: YourWalletsPresentationProtocol,
        didSelect address: AccountAddress
    ) {
        wireframe.hideYourWallets(from: selectionView)

        view?.didReceiveYourWallets(state: .inactive)
        updateRecepientAddress(address)
        provideInputViewModel()
    }

    func yourWalletsDidClose(selectionView _: YourWalletsPresentationProtocol) {
        view?.didReceiveYourWallets(state: .inactive)
    }
}

extension StakingSetupProxyPresenter: AddressScanDelegate {
    func addressScanDidReceiveRecepient(address: AccountAddress, context _: AnyObject?) {
        wireframe.hideAddressScan(from: view)

        updateRecepientAddress(address)
        provideInputViewModel()
    }
}
