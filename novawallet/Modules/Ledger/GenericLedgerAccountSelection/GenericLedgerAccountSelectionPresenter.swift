import Foundation
import Operation_iOS
import SubstrateSdk
import Foundation_iOS

final class GenericLedgerAccountSelectionPresenter {
    weak var view: GenericLedgerAccountSelectionViewProtocol?
    let wireframe: GenericLedgerAccountSelectionWireframeProtocol
    let interactor: GenericLedgerAccountSelectionInteractorInputProtocol
    let assetTokenFormatter: AssetBalanceFormatterFactoryProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private var availableChainAssets: [ChainAsset] = []
    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var selectedChainAsset: ChainAsset?
    private var accounts: [LedgerAccountAmount] = []

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        interactor: GenericLedgerAccountSelectionInteractorInputProtocol,
        wireframe: GenericLedgerAccountSelectionWireframeProtocol,
        assetTokenFormatter: AssetBalanceFormatterFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.assetTokenFormatter = assetTokenFormatter
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func performLoadNext() {
        let index = accounts.count

        guard index <= UInt32.max, let selectedChainAsset else {
            return
        }

        view?.didStartLoading()

        interactor.loadBalance(for: selectedChainAsset, at: UInt32(index))
    }

    private func addAccountViewModel(for account: LedgerAccountAmount) {
        guard let selectedChainAsset else {
            return
        }

        let icon = try? iconGenerator.generateFromAddress(account.address)
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }

        let assetDisplayInfo = selectedChainAsset.assetDisplayInfo
        let decimalAmount = account.amount?.decimal(assetInfo: assetDisplayInfo) ?? 0

        let tokenFormatter = assetTokenFormatter.createTokenFormatter(for: assetDisplayInfo)
        let amount = tokenFormatter.value(for: localizationManager.selectedLocale).stringFromDecimal(decimalAmount)

        let viewModel = LedgerAccountViewModel(
            address: account.address,
            icon: iconViewModel,
            amount: amount ?? ""
        )

        view?.didAddAccount(viewModel: viewModel)
    }

    private func shouldSwitchSelectedAsset() -> Bool {
        guard let selectedChainAsset, let chain = chains[selectedChainAsset.chain.chainId] else {
            return true
        }

        return selectedChainAsset.asset != chain.utilityAsset()
    }
}

extension GenericLedgerAccountSelectionPresenter: GenericLedgerAccountSelectionPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectAccount(at index: Int) {
        guard index < accounts.count else {
            return
        }

        wireframe.showWalletCreate(from: view, index: UInt32(index))
    }

    func loadNext() {
        performLoadNext()
    }
}

extension GenericLedgerAccountSelectionPresenter: GenericLedgerAccountSelectionInteractorOutputProtocol {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)
        availableChainAssets = Array(chains.values).sortedUsingDefaultComparator().compactMap { $0.utilityChainAsset() }

        if shouldSwitchSelectedAsset() {
            view?.didClearAccounts()

            selectedChainAsset = availableChainAssets.first
            accounts = []

            performLoadNext()
        }
    }

    func didReceive(accountBalance: LedgerAccountAmount, at index: UInt32) {
        if index == accounts.count {
            view?.didStopLoading()

            accounts.append(accountBalance)
            addAccountViewModel(for: accountBalance)
        }
    }

    func didReceive(error: GenericLedgerAccountInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .accountBalanceFetch:
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.performLoadNext()
            }
        }
    }
}
