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

    private var availableSchemes: Set<GenericLedgerAddressScheme> = []
    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var accounts: [GenericLedgerIndexedAccountModel] = []

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

        guard index <= UInt32.max else {
            return
        }

        view?.didStartLoading()

        interactor.loadAccounts(at: index, schemes: availableSchemes)
    }

    private func addAccountViewModel(for account: GenericLedgerIndexedAccountModel) {
        guard let address = account.accounts.first?.address else {
            return
        }

        let icon = try? iconGenerator.generateFromAddress(address)
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
        
        let newSchemes: Set<GenericLedgerAddressScheme> = chains.values.reduce(into: []) { accum, model in
            if model.isEthereumBased {
                accum.insert(.evm)
            } else {
                accum.insert(.substrate)
            }
        }
        

        if availableSchemes != newSchemes {
            view?.didClearAccounts()

            availableSchemes = newSchemes
            accounts = []

            performLoadNext()
        }
    }
    
    func didReceive(indexedAccount: GenericLedgerIndexedAccountModel) {
        if accountsResult.index == accounts.count {
            view?.didStopLoading()
            
            accounts.append(accountsResult)
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
