import Foundation
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

    var childPresenter: TransferSetupChildPresenterProtocol?

    private(set) var destinationChainAsset: ChainAsset?
    private(set) var availableDestinations: [ChainAsset]?
    private(set) var xcmTransfers: XcmTransfers?
    private var metaChainAccountResponses: [MetaAccountChainResponse] = []

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
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.originChainAsset = originChainAsset
        self.childPresenterFactory = childPresenterFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
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
}

extension TransferSetupPresenter: TransferSetupPresenterProtocol {
    func setup() {
        provideChainsViewModel()
        childPresenter?.setup()

        let destinationChain = destinationChainAsset?.chain ?? originChainAsset.chain
        interactor.setup(destinationChain: destinationChain)
    }

    func updateRecepient(partialAddress: String) {
        childPresenter?.updateRecepient(partialAddress: partialAddress)
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

        childPresenter?.changeRecepient(address: address)
    }

    func proceed() {
        childPresenter?.proceed()
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

        _ = wireframe.present(error: error, from: view, locale: view?.selectedLocale)
    }

    func didReceive(metaChainAccountResponses: [MetaAccountChainResponse]) {
        self.metaChainAccountResponses = metaChainAccountResponses
        updateYourWalletsButton()
    }
}

extension TransferSetupPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModel(at index: Int, section: Int, context: AnyObject?) {
        view?.didCompleteDestinationSelection()

        guard let selectionState = context as? CrossChainDestinationSelectionState else {
            return
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
            interactor.destinationChainDidChanged(destinationChainAsset.chain)
        } else {
            setupOnChainChildPresenter()
            interactor.destinationChainDidChanged(originChainAsset.chain)
        }
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        view?.didCompleteDestinationSelection()
    }
}

extension TransferSetupPresenter: AddressScanDelegate {
    func addressScanDidReceiveRecepient(address: AccountAddress, context _: AnyObject?) {
        wireframe.hideRecepientScan(from: view)

        childPresenter?.changeRecepient(address: address)
    }
}

extension TransferSetupPresenter: YourWalletsDelegate {
    func didSelectYourWallet(address: AccountAddress) {
        wireframe.hideYourWallets(from: view)

        childPresenter?.changeRecepient(address: address)
        view?.changeYourWalletsViewState(.inactive)
    }

    func didCloseYourWalletSelection() {
        view?.changeYourWalletsViewState(.inactive)
    }
}
