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
                view?.didReceiveKiltRecipient(viewModel: .loaded(value: nil))
            case let .external(externalAccount):
                view?.didReceiveKiltRecipient(viewModel: .loaded(value: externalAccount.address))
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

    private func showKiltAddressList(kiltRecipients: [KiltTransferAssetRecipientAccount], for name: String) {
        guard let view = view else {
            return
        }

        view.didReceiveKiltRecipient(viewModel: .cached(value: nil))
        let viewModel = web3NameViewModelFactory.recipientListViewModel(
            kiltRecipients: kiltRecipients,
            for: name,
            chainName: destinationChainName,
            selectedAddress: recipientAddress?.address
        )

        wireframe.presentWeb3NameAddressListPicker(from: view, viewModel: viewModel, delegate: self)
    }

    private func provideKiltRecipientViewModel(_ recipient: KiltTransferAssetRecipientAccount?, name: String) {
        guard let recipient = recipient else {
            if recipientAddress?.isExternal == true {
                recipientAddress = .external(.init(name: name))
                view?.didReceiveRecipientInputState(focused: true, empty: true)
            }
            return
        }
        if recipient.isValid(using: destinationChainAsset?.chain.chainFormat) {
            recipientAddress = .external(.init(name: name, address: recipient.account))
            childPresenter?.updateRecepient(partialAddress: recipient.account)
            view?.didReceiveRecipientInputState(focused: false, empty: nil)
        } else {
            recipientAddress = .external(.init(name: name))
            didReceive(error: Web3NameServiceError.invalidAddress(destinationChainName))
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
            recipientAddress = .external(.init(name: KiltW3n.fullName(for: w3n)))
        } else {
            recipientAddress = .address(partialAddress)
        }

        childPresenter?.updateRecepient(partialAddress: recipientAddress?.address ?? partialAddress)
        view?.didReceiveKiltRecipient(viewModel: .loaded(value: nil))
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
            if externalAccount.address == nil {
                didReceive(error: Web3NameServiceError.searchInProgress(externalAccount.name))
            } else {
                childPresenter?.proceed()
            }
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
        guard let web3Name = KiltW3n.web3Name(nameWithScheme: recipient) else {
            return
        }
        recipientAddress = .external(.init(name: KiltW3n.fullName(for: web3Name)))
        interactor.search(web3Name: web3Name)
    }

    func showOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: originChainAsset.chain,
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
                self?.recipientAddress = .external(.init(name: self?.recipientAddress?.name ?? ""))
            }
        } else {
            _ = wireframe.present(error: error, from: view, locale: view?.selectedLocale)
        }
    }

    func didReceive(metaChainAccountResponses: [MetaAccountChainResponse]) {
        self.metaChainAccountResponses = metaChainAccountResponses
        updateYourWalletsButton()
    }

    func didReceive(kiltRecipients: [KiltTransferAssetRecipientAccount], for name: String) {
        if kiltRecipients.count > 1 {
            showKiltAddressList(kiltRecipients: kiltRecipients, for: name)
        } else {
            provideKiltRecipientViewModel(kiltRecipients.first, name: name)
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
        guard let selectionState = context as? KiltAddressesSelectionState else {
            return
        }

        let selectedAccount = selectionState.accounts[index]
        provideKiltRecipientViewModel(selectedAccount, name: selectionState.name)
    }

    func modalPickerDidCancel(context: AnyObject?) {
        if context is CrossChainDestinationSelectionState {
            view?.didCompleteDestinationSelection()
        } else if context is KiltAddressesSelectionState {
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
