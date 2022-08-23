import Foundation
import SubstrateSdk
import SoraFoundation

final class LedgerAccountConfirmationPresenter {
    weak var view: LedgerAccountConfirmationViewProtocol?
    let wireframe: LedgerAccountConfirmationWireframeProtocol
    let interactor: LedgerAccountConfirmationInteractorInputProtocol
    let tokenFormatter: LocalizableResource<TokenFormatter>
    let chain: ChainModel
    let localizationManager: LocalizationManagerProtocol

    private var accounts: [LedgerAccountAmount] = []

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        interactor: LedgerAccountConfirmationInteractorInputProtocol,
        wireframe: LedgerAccountConfirmationWireframeProtocol,
        chain: ChainModel,
        tokenFormatter: LocalizableResource<TokenFormatter>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.tokenFormatter = tokenFormatter
        self.localizationManager = localizationManager
    }

    func performLoadNext() {
        guard accounts.count <= UInt32.max else {
            return
        }

        view?.didStartLoading()

        interactor.fetchAccount(for: UInt32(accounts.count))
    }

    func addAccountViewModel(for account: LedgerAccountAmount) {
        let icon = try? iconGenerator.generateFromAddress(account.address)
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }

        let decimalAmount: Decimal = account.amount.flatMap { amountInPlank in
            guard let asset = chain.utilityAsset() else {
                return nil
            }

            return Decimal.fromSubstrateAmount(amountInPlank, precision: Int16(bitPattern: asset.precision))
        } ?? 0

        let amount = tokenFormatter.value(for: localizationManager.selectedLocale).stringFromDecimal(decimalAmount)

        let viewModel = LedgerAccountViewModel(
            address: account.address,
            icon: iconViewModel,
            amount: amount ?? ""
        )

        view?.didAddAccount(viewModel: viewModel)
    }

    private func handle(error: Error, retryClosure: @escaping () -> Void) {
        guard let view = view else {
            return
        }

        if let ledgerError = error as? LedgerError {
            wireframe.presentLedgerError(
                on: view,
                error: ledgerError,
                networkName: chain.name,
                locale: localizationManager.selectedLocale,
                retryClosure: retryClosure
            )
        } else {
            _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)
        }
    }
}

extension LedgerAccountConfirmationPresenter: LedgerAccountConfirmationPresenterProtocol {
    func setup() {
        performLoadNext()
    }

    func selectAccount(at index: Int) {
        let account = accounts[index]

        interactor.confirm(address: account.address, at: UInt32(index))
    }

    func loadNext() {
        performLoadNext()
    }
}

extension LedgerAccountConfirmationPresenter: LedgerAccountConfirmationInteractorOutputProtocol {
    func didReceiveAccount(result: Result<LedgerAccountAmount, Error>, at index: UInt32) {
        view?.didStopLoading()

        switch result {
        case let .success(account):
            if index == accounts.count {
                accounts.append(account)
                addAccountViewModel(for: account)
            }
        case let .failure(error):
            handle(error: error) { [weak self] in
                self?.performLoadNext()
            }
        }
    }

    func didReceiveConfirmation(result: Result<AccountId, Error>, at index: UInt32) {
        switch result {
        case .success:
            wireframe.complete(on: view)
        case let .failure(error):
            handle(error: error) { [weak self] in
                self?.selectAccount(at: Int(index))
            }
        }
    }
}
