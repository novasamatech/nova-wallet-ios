import Foundation
import SubstrateSdk
import Foundation_iOS

final class TransferSetupPresenter {
    weak var view: TransferSetupViewProtocol?

    let interactor: TransferSetupInteractorIntputProtocol
    let wireframe: TransferSetupWireframeProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol

    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let whoChainAssetPeer: TransferSetupPeer
    let childPresenterFactory: TransferSetupPresenterFactoryProtocol
    let logger: LoggerProtocol
    let web3NameViewModelFactory: Web3NameViewModelFactoryProtocol

    var childPresenter: TransferSetupChildPresenterProtocol?

    private(set) var peerChainAsset: ChainAsset?
    private(set) var availablePeers: [ChainAsset]?
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

    private var originChainAsset: ChainAsset? {
        switch whoChainAssetPeer {
        case .origin:
            return peerChainAsset
        case .destination:
            return chainAsset
        }
    }

    private var destinationChainAsset: ChainAsset? {
        switch whoChainAssetPeer {
        case .origin:
            return chainAsset
        case .destination:
            return peerChainAsset
        }
    }

    private var destinationChainName: String {
        destinationChainAsset?.chain.name ?? ""
    }

    private var isOnChainTransfer: Bool {
        peerChainAsset == nil
    }

    init(
        interactor: TransferSetupInteractorIntputProtocol,
        wireframe: TransferSetupWireframeProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        whoChainAssetPeer: TransferSetupPeer,
        chainAssetPeers: [ChainAsset]?,
        childPresenterFactory: TransferSetupPresenterFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        web3NameViewModelFactory: Web3NameViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.whoChainAssetPeer = whoChainAssetPeer
        peerChainAsset = chainAssetPeers?.first
        availablePeers = chainAssetPeers
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
            for: chainAsset,
            initialState: initialState,
            view: view
        )

        view.didSwitchOnChain()

        childPresenter?.setup()
    }

    private func setupCrossChainChildPresenter() {
        guard
            let view = view,
            let originChainAsset = originChainAsset,
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
        let mode: TransferNetworkContainerViewModel.Mode
        let chainAssetViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)

        let optPeerChainAsset: ChainAsset?

        if let availablePeers = availablePeers, !availablePeers.isEmpty {
            optPeerChainAsset = peerChainAsset ?? chainAsset
        } else {
            optPeerChainAsset = peerChainAsset
        }

        if let peerChainAsset = optPeerChainAsset {
            let peerAssetViewModel = networkViewModelFactory.createViewModel(from: peerChainAsset.chain)

            switch whoChainAssetPeer {
            case .origin:
                mode = .selectableOrigin(peerAssetViewModel, chainAssetViewModel)
            case .destination:
                mode = .selectableDestination(chainAssetViewModel, peerAssetViewModel)
            }
        } else {
            mode = .onchain(chainAssetViewModel)
        }

        let viewModel = TransferNetworkContainerViewModel(assetSymbol: chainAsset.asset.symbol, mode: mode)

        view?.didReceiveSelection(viewModel: viewModel)
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

        let chain = destinationChainAsset?.chain ?? chainAsset.chain
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

        let chain = destinationChainAsset?.chain ?? chainAsset.chain

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

    private func selectDestinationChain() {
        let chain = chainAsset.chain
        let selectedChainId = peerChainAsset?.chain.chainId ?? chain.chainId

        let availablePeerChains = availablePeers?.map(\.chain) ?? []

        let selectionState = CrossChainDestinationSelectionState(
            chain: chain,
            availablePeerChains: availablePeerChains,
            selectedChainId: selectedChainId
        )

        wireframe.showDestinationChainSelection(
            from: view,
            selectionState: selectionState,
            delegate: self
        )
    }

    private func selectOriginChain() {
        let selectedChainAssetId = peerChainAsset?.chainAssetId ?? chainAsset.chainAssetId

        let peers = availablePeers ?? []

        let selectionState = CrossChainOriginSelectionState(
            availablePeerChainAssets: peers,
            selectedChainAssetId: selectedChainAssetId
        )

        wireframe.showOriginChainSelection(
            from: view,
            chainAsset: chainAsset,
            selectionState: selectionState,
            delegate: self
        )
    }

    private func handleNewChainAssetSelection(_ newPeerChainAsset: ChainAsset?) {
        if recipientAddress?.isExternal == true {
            recipientAddress = nil
            childPresenter?.updateRecepient(partialAddress: "")
        }

        peerChainAsset = newPeerChainAsset

        provideChainsViewModel()
        updateYourWalletsButton()

        if let peerChainAsset = peerChainAsset {
            setupCrossChainChildPresenter()
            interactor.peerChainAssetDidChanged(peerChainAsset)
        } else {
            setupOnChainChildPresenter()
            interactor.peerChainAssetDidChanged(chainAsset)
        }
    }
}

extension TransferSetupPresenter: TransferSetupPresenterProtocol {
    func setup() {
        provideChainsViewModel()
        childPresenter?.setup()

        interactor.setup(peerChainAsset: peerChainAsset ?? chainAsset)
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
        wireframe.showAddressScan(from: view, delegate: self)
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

    func selectChain() {
        switch whoChainAssetPeer {
        case .destination:
            selectDestinationChain()
        case .origin:
            selectOriginChain()
        }
    }

    func didTapOnYourWallets() {
        wireframe.showYourWallets(
            from: view,
            accounts: getYourWallets(),
            address: childPresenter?.inputState.recepient,
            delegate: self
        )
    }

    func editFeeAsset() {
        guard
            let utilityAsset = chainAsset.chain.utilityChainAsset(),
            let feeAsset = childPresenter?.getFeeAsset()
        else {
            return
        }

        wireframe.showFeeAssetSelection(
            from: view,
            utilityAsset: utilityAsset,
            sendingAsset: chainAsset,
            currentFeeAsset: feeAsset,
            onFeeAssetSelect: { [weak self] selectedAsset in
                self?.childPresenter?.changeFeeAsset(to: selectedAsset)
            }
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

        let chain = destinationChainAsset?.chain ?? chainAsset.chain

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: view.selectedLocale
        )
    }
}

extension TransferSetupPresenter: TransferSetupInteractorOutputProtocol {
    func didReceiveAvailableXcm(peerChainAssets: [ChainAsset], xcmTransfers: XcmTransfers?) {
        let symbol = chainAsset.asset.symbol
        let chainName = chainAsset.chain.name
        logger.debug("(\(chainName) \(symbol) Available peers: \(peerChainAssets.count)")

        availablePeers = peerChainAssets
        self.xcmTransfers = xcmTransfers

        if
            let peerChainAsset = peerChainAsset,
            !peerChainAssets.contains(where: { $0.chainAssetId == peerChainAsset.chainAssetId }) {
            self.peerChainAsset = nil

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
        view?.didCompleteChainSelection()

        if let selectionState = context as? CrossChainDestinationSelectionState {
            if section == 0 {
                handleNewChainAssetSelection(nil)
            } else {
                let selectedChain = selectionState.availablePeerChains[index]
                let selectedChainId = selectedChain.chainId

                let newPeerChainAsset = availablePeers?.first { $0.chain.chainId == selectedChainId }

                handleNewChainAssetSelection(newPeerChainAsset)
            }
        }
    }

    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        if let selectionState = context as? Web3NameAddressesSelectionState {
            let selectedAccount = selectionState.accounts[index]
            provideWeb3NameRecipientViewModel(selectedAccount, name: selectionState.name)
        } else if let selectionState = context as? CrossChainOriginSelectionState {
            handleNewChainAssetSelection(selectionState.availablePeerChainAssets[index])
        }
    }

    func modalPickerDidCancel(context: AnyObject?) {
        if context is CrossChainDestinationSelectionState || context is CrossChainOriginSelectionState {
            view?.didCompleteChainSelection()
        } else if context is Web3NameAddressesSelectionState {
            view?.didReceiveRecipientInputState(focused: true, empty: nil)
        }
    }
}

extension TransferSetupPresenter: AddressScanDelegate {
    func addressScanDidReceiveRecepient(address: AccountAddress, context _: AnyObject?) {
        wireframe.hideAddressScan(from: view)

        recipientAddress = .address(address)
        childPresenter?.changeRecepient(address: address)
    }
}

extension TransferSetupPresenter: YourWalletsDelegate {
    func yourWallets(
        selectionView: YourWalletsPresentationProtocol,
        didSelect address: AccountAddress
    ) {
        wireframe.hideYourWallets(from: selectionView)

        childPresenter?.changeRecepient(address: address)
        view?.changeYourWalletsViewState(.inactive)
        recipientAddress = .address(address)
    }

    func yourWalletsDidClose(
        selectionView _: YourWalletsPresentationProtocol
    ) {
        view?.changeYourWalletsViewState(.inactive)
    }
}
