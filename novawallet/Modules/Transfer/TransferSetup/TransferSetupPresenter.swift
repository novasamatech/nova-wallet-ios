import Foundation
import SubstrateSdk
import SoraFoundation

final class TransferSetupPresenter {
    weak var view: TransferSetupViewProtocol?

    let interactor: TransferSetupInteractorIntputProtocol
    let wireframe: TransferSetupWireframeProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol

    let wallet: MetaAccountModel
    let originChainAsset: ChainAsset
    let childPresenterFactory: TransferSetupPresenterFactoryProtocol
    let logger: LoggerProtocol
    let web3NameViewModelFactory: Web3NameViewModelFactoryProtocol

    var childPresenter: TransferSetupChildPresenterProtocol?

    private(set) var destinationChainAsset: ChainAsset?
    private(set) var availableDestinations: [ChainAsset]?
    private(set) var xcmTransfers: XcmTransfers?
    private(set) var recipientAddress: TransferSetupRecipientAccount? {
        didSet {
            switch recipientAddress {
            case .none, .address:
                view?.didReceiveWeb3NameRecipient(viewModel: .loaded(value: nil))
            case let .external(externalAccount):
                let isLoading = externalAccount.recipient.isLoading == true
                view?.didReceiveWeb3NameRecipient(viewModel: isLoading ? .loading :
                    .loaded(value: externalAccount.recipient.value??.displayTitle))
            }
        }
    }

    private var metaChainAccountResponses: [MetaAccountChainResponse] = []
    private var destinationChainName: String {
        destinationChainAsset?.chain.name ?? ""
    }

    private var isOnChainTransfer: Bool {
        destinationChainAsset == nil
    }

    init(
        interactor: TransferSetupInteractorIntputProtocol,
        wireframe: TransferSetupWireframeProtocol,
        wallet: MetaAccountModel,
        originChainAsset: ChainAsset,
        childPresenterFactory: TransferSetupPresenterFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        web3NameViewModelFactory: Web3NameViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.originChainAsset = originChainAsset
        self.childPresenterFactory = childPresenterFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.web3NameViewModelFactory = web3NameViewModelFactory
        self.logger = logger
    }

    private func setupOnChainChildPresenter() {
        guard let view = view else {
            return
        }

        let initialState = childPresenter?.inputState ?? TransferSetupInputState()

        childPresenter = childPresenterFactory.createOnChainPresenter(
            for: originChainAsset,
            initialState: initialState,
            view: view
        )

        view.didSwitchOnChain()

        childPresenter?.setup()
    }

    private func setupCrossChainChildPresenter() {
        guard
            let view = view,
            let destinationChainAsset = destinationChainAsset,
            let xcmTransfers = xcmTransfers else {
            return
        }

        let initialState = childPresenter?.inputState ?? TransferSetupInputState()

        childPresenter = childPresenterFactory.createCrossChainPresenter(
            for: originChainAsset,
            destinationChainAsset: destinationChainAsset,
            xcmTransfers: xcmTransfers,
            initialState: initialState,
            view: view
        )

        view.didSwitchCrossChain()

        childPresenter?.setup()
    }

    private func provideChainsViewModel() {
        let originViewModel = chainAssetViewModelFactory.createViewModel(from: originChainAsset)

        let destinationViewModel: NetworkViewModel?

        if let destinationChainAsset = destinationChainAsset {
            destinationViewModel = networkViewModelFactory.createViewModel(from: destinationChainAsset.chain)
        } else if let availableDestinations = availableDestinations, !availableDestinations.isEmpty {
            destinationViewModel = networkViewModelFactory.createViewModel(from: originChainAsset.chain)
        } else {
            destinationViewModel = nil
        }

        view?.didReceiveOriginChain(originViewModel, destinationChain: destinationViewModel)
    }

    private func getYourWallets() -> [MetaAccountChainResponse] {
        if isOnChainTransfer {
            return metaChainAccountResponses.filter { $0.metaAccount.metaId != wallet.metaId }
        } else {
            return metaChainAccountResponses
        }
    }

    func updateYourWalletsButton() {
        let isShowYourWallets = getYourWallets().contains { $0.chainAccountResponse != nil }

        view?.changeYourWalletsViewState(isShowYourWallets ? .inactive : .hidden)
    }

    private func showWeb3NameAddressList(recipients: [Web3TransferRecipient], for name: String) {
        guard let view = view else {
            return
        }

        let chain = destinationChainAsset?.chain ?? originChainAsset.chain
        view.didReceiveWeb3NameRecipient(viewModel: .cached(value: nil))
        let viewModel = web3NameViewModelFactory.recipientListViewModel(
            recipients: recipients,
            for: name,
            chain: chain,
            selectedAddress: recipientAddress?.address
        )

        wireframe.presentWeb3NameAddressListPicker(from: view, viewModel: viewModel, delegate: self)
    }

    private func provideWeb3NameRecipientViewModel(_ recipient: Web3TransferRecipient?, name: String) {
        guard let recipient = recipient else {
            if recipientAddress?.isExternal == true {
                recipientAddress = .external(.init(name: name, recipient: .loaded(value: nil)))
                view?.didReceiveRecipientInputState(focused: true, empty: true)
            }
            return
        }

        let chain = destinationChainAsset?.chain ?? originChainAsset.chain

        if let account = recipient.normalizedAddress(for: chain.chainFormat) {
            let recipientViewModel = TransferSetupRecipientAccount.ExternalAccountValue(
                address: account,
                description: recipient.description
            )
            recipientAddress = .external(.init(name: name, recipient: .loaded(value: recipientViewModel)))
            childPresenter?.updateRecepient(partialAddress: account)
            view?.didReceiveRecipientInputState(focused: false, empty: nil)
        } else {
            recipientAddress = .external(.init(name: name, recipient: .loaded(value: nil)))
            didReceive(error: Web3NameServiceError.invalidAddress(destinationChainName))
        }
    }

    private func proceedWithExternal(account: TransferSetupRecipientAccount.ExternalAccount) {
        switch account.recipient {
        case let .cached(value), let .loaded(value):
            if value?.address == nil {
                didReceive(error: Web3NameServiceError.accountNotFound(account.name))
            } else {
                childPresenter?.proceed()
            }
        case .loading:
            // wait the result
            break
        }
    }
}

extension TransferSetupPresenter: TransferSetupPresenterProtocol {
    func setup() {
        provideChainsViewModel()
        childPresenter?.setup()

        interactor.setup(destinationChainAsset: destinationChainAsset ?? originChainAsset)
    }

    func updateRecepient(partialAddress: String) {
        if let w3n = KiltW3n.web3Name(nameWithScheme: partialAddress) {
            recipientAddress = .external(.init(
                name: KiltW3n.fullName(for: w3n),
                recipient: .cached(value: nil)
            ))
        } else {
            recipientAddress = .address(partialAddress)
        }

        childPresenter?.updateRecepient(partialAddress: recipientAddress?.address ?? partialAddress)
        view?.didReceiveWeb3NameRecipient(viewModel: .loaded(value: nil))
    }

    func updateAmount(_ newValue: Decimal?) {
        childPresenter?.updateAmount(newValue)
    }

    func selectAmountPercentage(_ percentage: Float) {
        childPresenter?.selectAmountPercentage(percentage)
    }

    func scanRecepientCode() {
        wireframe.showRecepientScan(from: view, delegate: self)
    }

    func applyMyselfRecepient() {
        guard
            let destinationChain = destinationChainAsset?.chain,
            let address = wallet.fetch(for: destinationChain.accountRequest())?.toAddress() else {
            return
        }

        recipientAddress = .address(address)
        childPresenter?.changeRecepient(address: address)
    }

    func proceed() {
        switch recipientAddress {
        case .none, .address:
            childPresenter?.proceed()
        case let .external(externalAccount):
            proceedWithExternal(account: externalAccount)
        }
    }

    func changeDestinationChain() {
        let originChain = originChainAsset.chain
        let selectedChainId = destinationChainAsset?.chain.chainId ?? originChain.chainId

        let availableDestinationChains = availableDestinations?.map(\.chain) ?? []

        let selectionState = CrossChainDestinationSelectionState(
            originChain: originChain,
            availableDestChains: availableDestinationChains,
            selectedChainId: selectedChainId
        )

        wireframe.showDestinationChainSelection(
            from: view,
            selectionState: selectionState,
            delegate: self,
            context: selectionState
        )
    }

    func didTapOnYourWallets() {
        wireframe.showYourWallets(
            from: view,
            accounts: getYourWallets(),
            address: childPresenter?.inputState.recepient,
            delegate: self
        )
    }

    func complete(recipient: String) {
        guard !wireframe.checkDismissing(view: view) else {
            return
        }

        guard let web3Name = KiltW3n.web3Name(nameWithScheme: recipient) else {
            return
        }
        recipientAddress = .external(.init(
            name: KiltW3n.fullName(for: web3Name),
            recipient: .loading
        ))
        interactor.search(web3Name: web3Name)
    }

    func showWeb3NameRecipient() {
        guard let view = view, let address = recipientAddress?.address else {
            return
        }

        let chain = destinationChainAsset?.chain ?? originChainAsset.chain

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: view.selectedLocale
        )
    }
}

extension TransferSetupPresenter: TransferSetupInteractorOutputProtocol {
    func didReceiveAvailableXcm(destinations: [ChainAsset], xcmTransfers: XcmTransfers?) {
        let symbol = originChainAsset.asset.symbol
        let chainName = originChainAsset.chain.name
        logger.debug("(\(chainName) \(symbol) Available destinations: \(destinations.count)")

        availableDestinations = destinations
        self.xcmTransfers = xcmTransfers

        if
            let destinationChainAsset = destinationChainAsset,
            !destinations.contains(where: { $0.chainAssetId == destinationChainAsset.chainAssetId }) {
            self.destinationChainAsset = nil

            setupOnChainChildPresenter()
        }

        provideChainsViewModel()
    }

    func didReceive(error: Error) {
        logger.error("Did receive error: \(error)")

        if error is Web3NameServiceError {
            wireframe.present(
                error: error,
                from: view,
                locale: view?.selectedLocale
            ) { [weak self] in
                self?.view?.didReceiveRecipientInputState(focused: true, empty: nil)
                self?.recipientAddress = .external(.init(
                    name: self?.recipientAddress?.name ?? "",
                    recipient: .loaded(value: nil)
                ))
            }
        } else {
            _ = wireframe.present(error: error, from: view, locale: view?.selectedLocale)
        }
    }

    func didReceive(metaChainAccountResponses: [MetaAccountChainResponse]) {
        self.metaChainAccountResponses = metaChainAccountResponses
        updateYourWalletsButton()
    }

    func didReceive(recipients: [Web3TransferRecipient], for name: String) {
        if recipients.count > 1 {
            showWeb3NameAddressList(recipients: recipients, for: name)
        } else {
            provideWeb3NameRecipientViewModel(recipients.first, name: name)
        }
    }
}

extension TransferSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModel(at index: Int, section: Int, context: AnyObject?) {
        view?.didCompleteDestinationSelection()

        guard let selectionState = context as? CrossChainDestinationSelectionState else {
            return
        }

        if recipientAddress?.isExternal == true {
            recipientAddress = nil
            childPresenter?.updateRecepient(partialAddress: "")
        }

        if section == 0 {
            destinationChainAsset = nil
        } else {
            let selectedChain = selectionState.availableDestChains[index]
            let selectedChainId = selectedChain.chainId

            destinationChainAsset = availableDestinations?.first { $0.chain.chainId == selectedChainId }
        }

        provideChainsViewModel()
        updateYourWalletsButton()

        if let destinationChainAsset = destinationChainAsset {
            setupCrossChainChildPresenter()
            interactor.destinationChainAssetDidChanged(destinationChainAsset)
        } else {
            setupOnChainChildPresenter()
            interactor.destinationChainAssetDidChanged(originChainAsset)
        }
    }

    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let selectionState = context as? Web3NameAddressesSelectionState else {
            return
        }

        let selectedAccount = selectionState.accounts[index]
        provideWeb3NameRecipientViewModel(selectedAccount, name: selectionState.name)
    }

    func modalPickerDidCancel(context: AnyObject?) {
        if context is CrossChainDestinationSelectionState {
            view?.didCompleteDestinationSelection()
        } else if context is Web3NameAddressesSelectionState {
            view?.didReceiveRecipientInputState(focused: true, empty: nil)
        }
    }
}

extension TransferSetupPresenter: AddressScanDelegate {
    func addressScanDidReceiveRecepient(address: AccountAddress, context _: AnyObject?) {
        wireframe.hideRecepientScan(from: view)

        recipientAddress = .address(address)
        childPresenter?.changeRecepient(address: address)
    }
}

extension TransferSetupPresenter: YourWalletsDelegate {
    func didSelectYourWallet(address: AccountAddress) {
        wireframe.hideYourWallets(from: view)

        childPresenter?.changeRecepient(address: address)
        view?.changeYourWalletsViewState(.inactive)
        recipientAddress = .address(address)
    }

    func didCloseYourWalletSelection() {
        view?.changeYourWalletsViewState(.inactive)
    }
}
