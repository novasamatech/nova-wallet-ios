import Foundation
import Foundation_iOS
import BigInt
import SubstrateSdk

final class CrowdloanListPresenter {
    weak var view: CrowdloansViewProtocol?
    let wireframe: CrowdloanListWireframeProtocol
    let interactor: CrowdloanListInteractorInputProtocol
    let viewModelFactory: CrowdloansViewModelFactoryProtocol
    let logger: LoggerProtocol?
    let accountManagementFilter: AccountManagementFilterProtocol
    let wallet: MetaAccountModel

    private var selectedChainResult: Result<ChainModel, Error>?
    private var accountBalanceResult: Result<AssetBalance?, Error>?
    private var crowdloansResult: Result<[Crowdloan], Error>?
    private var displayInfoResult: Result<CrowdloanDisplayInfoDict, Error>?
    private var blockNumber: BlockNumber?
    private var blockDurationResult: Result<BlockTime, Error>?
    private var leasingPeriodResult: Result<LeasingPeriod, Error>?
    private var leasingOffsetResult: Result<LeasingOffset, Error>?
    private var priceDataResult: Result<PriceData?, Error>?
    private var contributionsResult: Result<CrowdloanContributionDict, Error>?
    private var externalContributions: [ExternalContribution]?
    private var leaseInfoResult: Result<ParachainLeaseInfoDict, Error>?

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
        logger: LoggerProtocol? = nil
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
        guard let chainResult = selectedChainResult else {
            return
        }

        guard
            case let .success(chain) = chainResult,
            let asset = chain.utilityAssets().first else {
            provideViewError(chainAsset: nil)
            return
        }

        let balance: BigUInt?

        if let accountBalanceResult = accountBalanceResult {
            balance = (try? accountBalanceResult.get()?.transferable) ?? 0
        } else {
            balance = nil
        }

        let viewModel = chainBalanceFactory.createViewModel(
            from: ChainAsset(chain: chain, asset: asset),
            balanceInPlank: balance,
            locale: selectedLocale
        )

        view?.didReceive(chainInfo: .wrapped(viewModel, with: privacyModeEnabled))
    }

    private func createMetadataResult() -> Result<CrowdloanMetadata, Error>? {
        guard
            let blockDurationResult = blockDurationResult,
            let leasingPeriodResult = leasingPeriodResult,
            let leasingOffsetResult = leasingOffsetResult,
            let blockNumber = blockNumber else {
            return nil
        }

        do {
            let blockDuration = try blockDurationResult.get()
            let leasingPeriod = try leasingPeriodResult.get()
            let leasingOffset = try leasingOffsetResult.get()

            let metadata = CrowdloanMetadata(
                blockNumber: blockNumber,
                blockDuration: blockDuration,
                leasingPeriod: leasingPeriod,
                leasingOffset: leasingOffset
            )

            return .success(metadata)
        } catch {
            return .failure(error)
        }
    }

    private func createViewInfoResult() -> Result<CrowdloansViewInfo, Error>? {
        guard
            let displayInfoResult = displayInfoResult,
            let metadataResult = createMetadataResult(),
            let contributionsResult = contributionsResult,
            let leaseInfoResult = leaseInfoResult else {
            return nil
        }

        do {
            let contributions = try contributionsResult.get()
            let leaseInfo = try leaseInfoResult.get()
            let metadata = try metadataResult.get()
            let displayInfo = try? displayInfoResult.get()

            let viewInfo = CrowdloansViewInfo(
                contributions: contributions,
                leaseInfo: leaseInfo,
                displayInfo: displayInfo,
                metadata: metadata
            )

            return .success(viewInfo)
        } catch {
            return .failure(error)
        }
    }

    private func updateListView() {
        guard let chainResult = selectedChainResult else {
            return
        }

        guard case let .success(chain) = chainResult, let asset = chain.utilityAssets().first else {
            provideViewError(chainAsset: nil)
            return
        }

        guard
            let crowdloansResult = crowdloansResult,
            let viewInfoResult = createViewInfoResult() else {
            return
        }

        let chainAsset = ChainAssetDisplayInfo(asset: asset.displayInfo, chain: chain.chainFormat)
        do {
            let crowdloans = try crowdloansResult.get()
            let priceData = try? priceDataResult?.get() ?? nil
            let viewInfo = try viewInfoResult.get()
            let externalContributionsCount = externalContributions?.count ?? 0

            let amount: Decimal?
            if let contributionsResult = try contributionsResult?.get() {
                amount = crowdloansCalculator.calculateTotal(
                    precision: chain.utilityAsset().map { Int16($0.precision) },
                    contributions: contributionsResult,
                    externalContributions: externalContributions ?? []
                )
            } else {
                amount = nil
            }

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
        } catch {
            provideViewError(chainAsset: chainAsset)
        }
    }

    private func openCrowdloan(for paraId: ParaId) {
        let displayInfoDict = try? displayInfoResult?.get()
        let displayInfo = displayInfoDict?[paraId]

        guard
            let crowdloans = try? crowdloansResult?.get(),
            let selectedCrowdloan = crowdloans.first(where: { $0.paraId == paraId })
        else { return }

        wireframe.presentContributionSetup(
            from: view,
            crowdloan: selectedCrowdloan,
            displayInfo: displayInfo
        )
    }

    private func provideViewError(chainAsset: ChainAssetDisplayInfo?) {
        let viewModel = viewModelFactory.createErrorViewModel(
            chainAsset: chainAsset,
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
        guard
            let chain = try? selectedChainResult?.get(),
            let asset = chain.utilityAsset() else {
            return
        }

        let chainAssetId = ChainAsset(chain: chain, asset: asset).chainAssetId

        wireframe.selectChain(
            from: view,
            delegate: self,
            selectedChainAssetId: chainAssetId
        )
    }
}

extension CrowdloanListPresenter: CrowdloanListPresenterProtocol {
    func refresh(shouldReset: Bool) {
        crowdloansResult = nil

        if shouldReset {
            view?.didReceive(listState: viewModelFactory.createLoadingViewModel())
        }

        if case .success = selectedChainResult {
            interactor.refresh()
        } else {
            interactor.setup()
        }
    }

    func selectCrowdloan(_ paraId: ParaId) {
        guard let chain = try? selectedChainResult?.get() else {
            return
        }

        if wallet.fetch(for: chain.accountRequest()) != nil {
            openCrowdloan(for: paraId)
        } else if accountManagementFilter.canAddAccount(to: wallet, chain: chain) {
            guard let view = view else {
                return
            }

            let message = R.string.localizable.commonChainCrowdloanAccountMissingMessage(
                chain.name,
                preferredLanguages: selectedLocale.rLanguages
            )

            wireframe.presentAddAccount(
                from: view,
                chainName: chain.name,
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
                chainName: chain.name,
                locale: selectedLocale
            )
        }
    }

    func handleYourContributions() {
        guard
            let chainResult = selectedChainResult,
            let crowdloansResult = crowdloansResult,
            let viewInfoResult = createViewInfoResult(),
            case let .success(chain) = chainResult,
            let asset = chain.utilityAssets().first
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
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>) {
        logger?.info("Did receive display info: \(result)")

        displayInfoResult = result
        updateListView()
    }

    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>) {
        logger?.info("Did receive crowdloans: \(result)")

        crowdloansResult = result
        updateListView()
    }

    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>) {
        switch result {
        case let .success(blockNumber):
            self.blockNumber = blockNumber

            updateListView()
        case let .failure(error):
            logger?.error("Did receivee block number error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        blockDurationResult = result
        updateListView()
    }

    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>) {
        leasingPeriodResult = result
        updateListView()
    }

    func didReceiveLeasingOffset(result: Result<LeasingOffset, Error>) {
        leasingOffsetResult = result
        updateListView()
    }

    func didReceiveContributions(result: Result<CrowdloanContributionDict, Error>) {
        if case let .failure(error) = result {
            logger?.error("Did receive contributions error: \(error)")
        }

        contributionsResult = result
        updateListView()
    }

    func didReceiveExternalContributions(result: Result<[ExternalContribution], Error>) {
        switch result {
        case let .success(contributions):
            let positiveContributions = contributions.filter { $0.amount > 0 }
            externalContributions = positiveContributions
            if !positiveContributions.isEmpty {
                updateListView()
            }
        case let .failure(error):
            logger?.error("Did receive external contributions error: \(error)")
        }
    }

    func didReceiveLeaseInfo(result: Result<ParachainLeaseInfoDict, Error>) {
        if case let .failure(error) = result {
            logger?.error("Did receive lease info error: \(error)")
        }

        leaseInfoResult = result
        updateListView()
    }

    func didReceiveSelectedChain(result: Result<ChainModel, Error>) {
        selectedChainResult = result
        updateChainView()
        updateListView()
    }

    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>) {
        accountBalanceResult = result
        updateChainView()
    }

    func didReceivePriceData(result: Result<PriceData?, Error>?) {
        priceDataResult = result
        updateListView()
    }
}

extension CrowdloanListPresenter: ChainAssetSelectionDelegate {
    func assetSelection(view _: ChainAssetSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset) {
        if let currentChain = try? selectedChainResult?.get(), currentChain.chainId == chainAsset.chain.chainId {
            return
        }

        selectedChainResult = .success(chainAsset.chain)
        accountBalanceResult = nil
        crowdloansResult = nil
        displayInfoResult = nil
        blockNumber = nil
        blockDurationResult = nil
        leasingPeriodResult = nil
        contributionsResult = nil
        leaseInfoResult = nil

        updateChainView()

        view?.didReceive(listState: viewModelFactory.createLoadingViewModel())

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
