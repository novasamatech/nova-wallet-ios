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
    private var accountBalance: UncertainStorage<AssetBalance?> = .undefined
    private var contributions: [CrowdloanContribution] = []
    private var displayInfo: CrowdloanDisplayInfoDict?
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

        let balance: Balance? = accountBalance
            .map { $0?.transferable ?? 0 }
            .valueWhenDefined(else: nil)

        let viewModel = chainBalanceFactory.createViewModel(
            from: ChainAsset(chain: chain, asset: asset),
            balanceInPlank: balance,
            locale: selectedLocale
        )

        view?.didReceive(chainInfo: .wrapped(viewModel, with: privacyModeEnabled))
    }

    private func createViewInfo() -> CrowdloansViewInfo? {
        guard let displayInfo else {
            return nil
        }

        return CrowdloansViewInfo(
            contributions: contributions,
            displayInfo: displayInfo
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
        // nothing special to do when page becomes active
    }

    func putOffline() {}

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

    func didReceiveSelectedChain(_ chain: ChainModel) {
        logger.debug("Chain: \(chain.name)")

        selectedChain = chain
        updateChainView()
        updateListView()
    }

    func didReceiveAccountBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance?.transferable))")

        accountBalance = .defined(balance)
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
        accountBalance = .undefined
        contributions = []
        displayInfo = nil
        priceData = nil

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
