import Foundation
import Operation_iOS
import Foundation_iOS

final class CrowdloanUnlockPresenter {
    weak var view: CrowdloanUnlockViewProtocol?
    let wireframe: CrowdloanUnlockWireframeProtocol
    let interactor: CrowdloanUnlockInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: CrowdloanDataValidatingFactoryProtocol
    let unlockModel: CrowdloanUnlock

    let logger: LoggerProtocol

    private var balance: AssetBalance?
    private var fee: ExtrinsicFeeProtocol?
    private var blockNumber: BlockNumber?
    private var price: PriceData?
    private var existentialDeposit: Balance?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: CrowdloanUnlockInteractorInputProtocol,
        wireframe: CrowdloanUnlockWireframeProtocol,
        unlockModel: CrowdloanUnlock,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: CrowdloanDataValidatingFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.unlockModel = unlockModel
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger

        self.localizationManager = localizationManager
    }
}

private extension CrowdloanUnlockPresenter {
    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        interactor.estimateFee(for: unlockModel.items)
    }

    /* func updateUnlocks() {
         guard let blockNumber else {
             return
         }

         let (newUnlocks, newTotalUnlock) = contributions.values.reduce(
             (Set<CrowdloanUnlock>(), Balance(0))
         ) { currentValue, contribution in
             guard contribution.unlocksAt <= blockNumber else {
                 return currentValue
             }

             let newAmount = currentValue.1 + contribution.amount
             let newUnlock = CrowdloanUnlock(
                 paraId: contribution.paraId,
                 block: contribution.unlocksAt
             )

             let newUnlocks = currentValue.0.union([newUnlock])

             return (newUnlocks, newAmount)
         }

         let hasChanges = newUnlocks != unlocks || totalUnlock != newTotalUnlock

         unlocks = newUnlocks
         totalUnlock = newTotalUnlock

         logger.debug("Unlocks count: \(newUnlocks.count)")
         logger.debug("Total unlock: \(newTotalUnlock)")

         if hasChanges {
             provideUnlockAmount()
             estimatedFee()
         }
     } */

    func provideUnlockAmount() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            unlockModel.amount.decimal(assetInfo: chainAsset.assetDisplayInfo),
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.map { fee in
            let amountDecimal = fee.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func applyCurrentState() {
        provideUnlockAmount()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
    }
}

extension CrowdloanUnlockPresenter: CrowdloanUnlockPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()
    }

    func selectAccount() {
        let chainFormat = chainAsset.chain.chainFormat

        guard let address = try? selectedAccount.chainAccount.accountId.toAddress(
            using: chainFormat
        ) else {
            return
        }

        presentOptions(for: address)
    }

    func confirm() {
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.notViolatingMinBalancePaying(
                fee: fee,
                total: balance?.balanceCountingEd,
                minBalance: existentialDeposit,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let self else {
                return
            }

            interactor.submit(unlocks: unlockModel.items)
        }
    }
}

extension CrowdloanUnlockPresenter: CrowdloanUnlockInteractorOutputProtocol {
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        balance = assetBalance
    }

    func didReceivePrice(_ price: PriceData?) {
        self.price = price

        provideFeeViewModel()
        provideUnlockAmount()
    }

    func didReceiveFeeResult(_ result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(fee):
            logger.debug("Fee: \(fee)")

            self.fee = fee

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Fee error: \(error)")

            wireframe.presentFeeStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveExistentialDeposit(_ existentialDeposit: Balance?) {
        logger.debug("Existential deposit: \(String(existentialDeposit ?? 0))")

        self.existentialDeposit = existentialDeposit
    }

    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(model):
            wireframe.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
                completionAction: .dismiss,
                locale: selectedLocale
            )
        case let .failure(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension CrowdloanUnlockPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyCurrentState()
        }
    }
}
