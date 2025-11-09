import Foundation
import Foundation_iOS
import BigInt
import SubstrateSdk

final class CrowdloanListPresenter {
    weak var view: CrowdloansViewProtocol?
    let wireframe: CrowdloanListWireframeProtocol
    let interactor: CrowdloanListInteractorInputProtocol
    let viewModelFactory: CrowdloansViewModelFactoryProtocol
    let logger: LoggerProtocol
    let accountManagementFilter: AccountManagementFilterProtocol
    let wallet: MetaAccountModel

    private var selectedChain: ChainModel?
    private var accountBalance: AssetBalance?
    private var contributions: [CrowdloanContribution]?
    private var displayInfo: CrowdloanDisplayInfoDict?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var priceData: PriceData?

    private let crowdloansCalculator: CrowdloansCalculatorProtocol

    private lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    init(
        interactor: CrowdloanListInteractorInputProtocol,
        wireframe: CrowdloanListWireframeProtocol,
        wallet: MetaAccountModel,
        viewModelFactory: CrowdloansViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        crowdloansCalculator: CrowdloansCalculatorProtocol,
        accountManagementFilter: AccountManagementFilterProtocol,
        appearanceFacade: AppearanceFacadeProtocol,
        privacyStateManager: PrivacyStateManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.crowdloansCalculator = crowdloansCalculator
        self.accountManagementFilter = accountManagementFilter
        self.appearanceFacade = appearanceFacade
        self.localizationManager = localizationManager
        self.privacyStateManager = privacyStateManager
    }

    private func updateChainView() {
        guard let asset = selectedChain.utilityAsset() else {
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
            let metadata = createMetadata(),
            let contributions else {
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
        
        let amount = crowdloansCalculator.calculateTotal(
            contributions: contributions,
            assetInfo: chainAsset.asset
        )

        let viewModel = viewModelFactory.createViewModel(
            from: crowdloans,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            externalContributionsCount: externalContributionsCount,
            amount: amount,
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
    func selectCrowdloan(_ paraId: ParaId) {
        guard let selectedChain else {
            return
        }

        if wallet.fetch(for: selectedChain.accountRequest()) != nil {
            openCrowdloan(for: paraId)
        } else if accountManagementFilter.canAddAccount(to: wallet, chain: selectedChain) {
            guard let view = view else {
                return
            }

            let message = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonChainCrowdloanAccountMissingMessage(selectedChain.name)

            wireframe.presentAddAccount(
                from: view,
                chainName: selectedChain.name,
                message: message,
                locale: selectedLocale
            ) { [weak self] in
                guard let wallet = self?.wallet else {
                    return
                }

                self?.wireframe.showWalletDetails(from: self?.view, wallet: wallet)
            }
        } else {
            guard let view = view else {
                return
            }

            wireframe.presentNoAccountSupport(
                from: view,
                walletType: wallet.type,
                chainName: selectedChain.name,
                locale: selectedLocale
            )
        }
    }

    func handleYourContributions() {
        guard
            let selectedChain,
            let contributions,
            let viewInfoResult = createViewInfoResult(),
            case let .success(chain) = chainResult,
            let asset = selectedChain.utilityAssets().first
        else { return }

        do {
            let crowdloans = try crowdloansResult.get()
            let viewInfo = try viewInfoResult.get()
            let chainAsset = ChainAssetDisplayInfo(asset: asset.displayInfo, chain: chain.chainFormat)

            wireframe.showYourContributions(
                crowdloans: crowdloans,
                viewInfo: viewInfo,
                chainAsset: chainAsset,
                from: view
            )
        } catch {
            logger?.error(error.localizedDescription)
        }
    }
}

extension CrowdloanListPresenter: CrowdloanListInteractorOutputProtocol {
    func didReceiveContributions(_ contributions: [CrowdloanContribution]) {
        logger.debug("Contributions: \(contributions.count)")
        
        self.contributions = contributions
        updateListView()
    }
    
    func didReceiveDisplayInfo(_ info: CrowdloanDisplayInfoDict) {
        logger.info("Did receive display info: \(info)")

        displayInfo = info
        updateListView()
    }
    
    func didReceiveBlockNumber(_ blockNumber: BlockNumber?) {
        self.blockNumber = blockNumber

        updateListView()
    }
    
    func didReceiveBlockDuration(_ blockTime: BlockTime) {
        blockDuration = blockTime
        updateListView()
    }

    func didReceiveSelectedChain(_ chain: ChainModel) {
        selectedChain = chain
        updateChainView()
        updateListView()
    }
    
    func didReceiveAccountBalance(_ balance: AssetBalance?) {
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
        contributions = nil
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
