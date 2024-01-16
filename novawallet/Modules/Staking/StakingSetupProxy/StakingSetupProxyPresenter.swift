import Foundation
import BigInt
import SoraFoundation

final class StakingSetupProxyPresenter: StakingProxyBasePresenter {
    weak var view: StakingSetupProxyViewProtocol? {
        baseView as? StakingSetupProxyViewProtocol
    }

    let wireframe: StakingSetupProxyWireframeProtocol
    let interactor: StakingSetupProxyInteractorInputProtocol
    let web3NameViewModelFactory: Web3NameViewModelFactoryProtocol
    private(set) var recipientAddress: SetupRecipientAccount? {
        didSet {
            switch recipientAddress {
            case .none, .address:
                view?.didReceiveWeb3NameAuthority(viewModel: .loaded(value: nil))
            case let .external(externalAccount):
                let isLoading = externalAccount.recipient.isLoading == true
                view?.didReceiveWeb3NameAuthority(viewModel: isLoading ? .loading :
                    .loaded(value: externalAccount.recipient.value??.displayTitle))
            }
        }
    }

    private var yourWallets: [MetaAccountChainResponse] = []

    init(
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
        view.didReceiveWeb3NameAuthority(viewModel: .cached(value: nil))

        let viewModel = web3NameViewModelFactory.recipientListViewModel(
            recipients: recipients,
            for: name,
            chain: chain,
            selectedAddress: recipientAddress?.address
        )

        wireframe.presentWeb3NameAddressListPicker(from: view, viewModel: viewModel, delegate: self)
    }

    private func provideWeb3NameViewModel(_ authority: Web3TransferRecipient?, name: String) {
        guard let authority = authority else {
            if recipientAddress?.isExternal == true {
                recipientAddress = .external(.init(name: name, recipient: .loaded(value: nil)))
                view?.didReceiveAuthorityInputState(focused: true, empty: true)
            }
            return
        }

        let chain = chainAsset.chain

        if let account = authority.normalizedAddress(for: chain.chainFormat) {
            let authorityViewModel = SetupRecipientAccount.ExternalAccountValue(
                address: account,
                description: authority.description
            )
            recipientAddress = .external(.init(name: name, recipient: .loaded(value: authorityViewModel)))
            view?.didReceiveAuthorityInputState(focused: false, empty: nil)
        } else {
            recipientAddress = .external(.init(name: name, recipient: .loaded(value: nil)))
            didReceive(error: .web3Name(.invalidAddress(chain.name)))
        }
    }

    private func provideInputViewModel() {
        let value = recipientAddress?.address ?? ""

        let inputViewModel = InputViewModel.createAccountInputViewModel(for: value)

        view?.didReceiveAccountInput(viewModel: inputViewModel)
    }

    private func updateRecepientAddress(_ newAddress: String) {
        guard recipientAddress?.address != newAddress else {
            return
        }

        recipientAddress = .address(newAddress)
    }

    func updateYourWalletsButton() {
        let isShowYourWallets = yourWallets.contains { $0.chainAccountResponse != nil }
        view?.didReceiveYourWallets(state: isShowYourWallets ? .inactive : .hidden)
    }

    private func proceedWithExternal(account: SetupRecipientAccount.ExternalAccount) {
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
        let validations = createCommonValidations()

        DataValidationRunner(validators: validations).runValidation { [weak self] in
            guard
                let address = self?.recipientAddress?.address else {
                return
            }

            self?.wireframe.showConfirmation(
                from: self?.view,
                proxyAddress: address
            )
        }
    }
}

extension StakingSetupProxyPresenter: StakingSetupProxyPresenterProtocol {
    func complete(authority: String) {
        guard !wireframe.checkDismissing(view: view) else {
            return
        }

        guard let web3Name = KiltW3n.web3Name(nameWithScheme: authority) else {
            return
        }
        recipientAddress = .external(.init(
            name: KiltW3n.fullName(for: web3Name),
            recipient: .loading
        ))
        interactor.search(web3Name: web3Name)
    }

    func updateAuthority(partialAddress: String) {
        if let w3n = KiltW3n.web3Name(nameWithScheme: partialAddress) {
            recipientAddress = .external(.init(
                name: KiltW3n.fullName(for: w3n),
                recipient: .cached(value: nil)
            ))
        } else {
            recipientAddress = .address(partialAddress)
        }

        view?.didReceiveWeb3NameAuthority(viewModel: .loaded(value: nil))
    }

    func showWeb3NameAuthority() {
        guard let view = view, let address = recipientAddress?.address else {
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
            address: recipientAddress?.address,
            delegate: self
        )
    }

    func scanAddressCode() {
        wireframe.showAddressScan(from: view, delegate: self)
    }

    func proceed() {
        switch recipientAddress {
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
                self?.view?.didReceiveAuthorityInputState(focused: true, empty: nil)
                self?.recipientAddress = .external(.init(
                    name: self?.recipientAddress?.name ?? "",
                    recipient: .loaded(value: nil)
                ))
            }
        case let .fetchMetaAccounts(error):
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
        view?.didReceiveAuthorityInputState(focused: true, empty: nil)
    }
}

extension StakingSetupProxyPresenter: YourWalletsDelegate {
    func didSelectYourWallet(address: AccountAddress) {
        wireframe.hideYourWallets(from: view)
        view?.didReceiveYourWallets(state: .inactive)
        updateRecepientAddress(address)
        provideInputViewModel()
    }

    func didCloseYourWalletSelection() {
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

struct ProxyConfirmInputState {
    let delegatingAccount: AccountId
    let proxyDeposit: BigUInt
    let fee: BigUInt
    let proxy: AccountAddress
    let grantingAccess: Proxy.ProxyType
    let chainAsset: ChainAsset
}
