import Foundation
import Foundation_iOS
import Operation_iOS
import BigInt
import SubstrateSdk

final class CrowdloanListPresenter {
    weak var view: CrowdloansViewProtocol?
    let wireframe: CrowdloanListWireframeProtocol
    let interactor: CrowdloanListInteractorInputProtocol
    let viewModelFactory: CrowdloansViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var selectedChain: ChainModel?
    private var accountBalance: AssetBalance?
    private var contributions: [CrowdloanContribution] = []
    private var displayInfo: CrowdloanDisplayInfoDict?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var priceData: PriceData?

    private lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    init(
        interactor: CrowdloanListInteractorInputProtocol,
        wireframe: CrowdloanListWireframeProtocol,
        viewModelFactory: CrowdloansViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        appearanceFacade: AppearanceFacadeProtocol,
        privacyStateManager: PrivacyStateManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.appearanceFacade = appearanceFacade
        self.localizationManager = localizationManager
        self.privacyStateManager = privacyStateManager
    }

    private func updateChainView() {
        guard
            let chain = selectedChain,
            let asset = chain.utilityAsset() else {
            return
        }

        let balance = accountBalance?.transferable

        let viewModel = chainBalanceFactory.createViewModel(
            from: ChainAsset(chain: chain, asset: asset),
            balanceInPlank: balance,
            locale: selectedLocale
        )

        view?.didReceive(chainInfo: .wrapped(viewModel, with: privacyModeEnabled))
    }

    private func createMetadata() -> CrowdloanMetadata? {
        guard let blockDuration, let blockNumber else {
            return nil
        }

        return CrowdloanMetadata(blockNumber: blockNumber, blockDuration: blockDuration)
    }

    private func createViewInfo() -> CrowdloansViewInfo? {
        guard
            let displayInfo,
            let metadata = createMetadata() else {
            return nil
        }

        return CrowdloansViewInfo(
            contributions: contributions,
            displayInfo: displayInfo,
            metadata: metadata
        )
    }

    private func updateListView() {
        guard
            let chain = selectedChain,
            let asset = chain.utilityAsset() else {
            return
        }

        guard let viewInfo = createViewInfo() else {
            return
        }

        let chainAsset = ChainAssetDisplayInfo(asset: asset.displayInfo, chain: chain.chainFormat)

        let viewModel = viewModelFactory.createViewModel(
            from: viewInfo,
            chainAsset: chainAsset,
            priceData: priceData,
            locale: selectedLocale
        )

        view?.didReceive(listState: viewModel)
    }
}

extension CrowdloanListPresenter: VoteChildPresenterProtocol {
    func setup() {
        view?.didReceive(listState: viewModelFactory.createLoadingViewModel())

        interactor.setup()
    }

    func becomeOnline() {
        interactor.becomeOnline()
    }

    func putOffline() {
        interactor.putOffline()
    }

    func selectChain() {
        guard let chainAssetId = selectedChain?.utilityChainAssetId() else {
            return
        }

        wireframe.selectChain(
            from: view,
            delegate: self,
            selectedChainAssetId: chainAssetId
        )
    }
}

extension CrowdloanListPresenter: CrowdloanListPresenterProtocol {
    func handleYourContributions() {
        guard
            let viewInfo = createViewInfo(),
            let chainAsset = selectedChain?.utilityChainAsset()?.chainAssetInfo
        else {
            return
        }

        wireframe.showYourContributions(
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            from: view
        )
    }
}

extension CrowdloanListPresenter: CrowdloanListInteractorOutputProtocol {
    func didReceiveContributions(_ changes: [DataProviderChange<CrowdloanContribution>]) {
        let dict = contributions.reduceToDict()
        contributions = Array(changes.mergeToDict(dict).values).sortedByUnlockTime()

        logger.debug("Contributions: \(contributions.count)")

        updateListView()
    }

    func didReceiveDisplayInfo(_ info: CrowdloanDisplayInfoDict) {
        logger.debug("Did receive display info: \(info.count)")

        displayInfo = info
        updateListView()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber?) {
        logger.debug("Block number: \(String(describing: blockNumber))")

        self.blockNumber = blockNumber

        updateListView()
    }

    func didReceiveBlockDuration(_ blockTime: BlockTime) {
        logger.debug("Block duration: \(blockTime)")

        blockDuration = blockTime
        updateListView()
    }

    func didReceiveSelectedChain(_ chain: ChainModel) {
        logger.debug("Chain: \(chain.name)")

        selectedChain = chain
        updateChainView()
        updateListView()
    }

    func didReceiveAccountBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance?.transferable))")

        accountBalance = balance
        updateChainView()
    }

    func didReceivePriceData(_ price: PriceData?) {
        priceData = price
        updateListView()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Unexpected error: \(error)")

        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
    }
}

extension CrowdloanListPresenter: ChainAssetSelectionDelegate {
    func assetSelection(view _: ChainAssetSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset) {
        if let currentChain = selectedChain, currentChain.chainId == chainAsset.chain.chainId {
            return
        }

        selectedChain = chainAsset.chain
        accountBalance = nil
        contributions = []
        displayInfo = nil
        blockNumber = nil
        blockDuration = nil

        updateChainView()
        updateListView()

        interactor.saveSelected(chainModel: chainAsset.chain)
    }
}

extension CrowdloanListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateChainView()
            updateListView()
        }
    }
}

// MARK: IconAppearanceDepending

extension CrowdloanListPresenter: IconAppearanceDepending {
    func applyIconAppearance() {
        guard let view, view.isSetup else { return }

        updateChainView()
    }
}

// MARK: - PrivacyModeSupporting

extension CrowdloanListPresenter: PrivacyModeSupporting {
    func applyPrivacyMode() {
        guard let view, view.isSetup else { return }

        updateChainView()
    }
}
