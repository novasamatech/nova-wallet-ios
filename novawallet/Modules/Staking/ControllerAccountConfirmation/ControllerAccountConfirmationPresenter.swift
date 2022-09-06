import Foundation
import SoraFoundation
import SubstrateSdk
import BigInt

final class ControllerAccountConfirmationPresenter {
    weak var view: ControllerAccountConfirmationViewProtocol?
    var wireframe: ControllerAccountConfirmationWireframeProtocol!
    var interactor: ControllerAccountConfirmationInteractorInputProtocol!

    private let controllerAccountItem: MetaChainAccountResponse
    private let assetInfo: AssetBalanceDisplayInfo
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let logger: LoggerProtocol?
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let chain: ChainModel

    private var stashAccountItem: MetaChainAccountResponse?
    private var fee: Decimal?
    private var priceData: PriceData?
    private var balance: Decimal?
    private var stakingLedger: StakingLedger?

    private lazy var addressViewModelFactory = DisplayAddressViewModelFactory()
    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    init(
        controllerAccountItem: MetaChainAccountResponse,
        assetInfo: AssetBalanceDisplayInfo,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chain: ChainModel,
        logger: LoggerProtocol? = nil
    ) {
        self.controllerAccountItem = controllerAccountItem
        self.assetInfo = assetInfo
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chain = chain
        self.logger = logger
    }

    private func updateView() {
        guard
            let stashAccountItem = stashAccountItem,
            let stashAddress = stashAccountItem.chainAccount.toAddress(),
            let controllerAddress = controllerAccountItem.chainAccount.toAddress(),
            let walletViewModel = try? walletViewModelFactory.createDisplayViewModel(from: stashAccountItem)
        else { return }

        let accountViewModel = addressViewModelFactory.createViewModel(from: stashAddress)
        let controllerViewModel = addressViewModelFactory.createViewModel(from: controllerAddress)

        let viewModel = ControllerAccountConfirmationVM(
            walletViewModel: walletViewModel,
            accountViewModel: accountViewModel,
            controllerViewModel: controllerViewModel
        )

        view?.reload(with: viewModel)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func refreshFeeIfNeeded() {
        guard fee == nil else { return }
        interactor.estimateFee()
    }
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationPresenterProtocol {
    func setup() {
        provideFeeViewModel()
        interactor.setup()
    }

    func handleStashAction() {
        presentAccountOptions(for: stashAccountItem?.chainAccount.toAddress())
    }

    func handleControllerAction() {
        presentAccountOptions(for: controllerAccountItem.chainAccount.toAddress())
    }

    func confirm() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),
            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                asset: assetInfo,
                locale: locale
            ),
            dataValidatingFactory.ledgerNotExist(
                stakingLedger: stakingLedger,
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.view?.didStartLoading()
            self?.interactor.confirm()
        }
    }

    private func presentAccountOptions(for address: AccountAddress?) {
        guard
            let view = view,
            let address = address
        else { return }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: view.localizationManager?.selectedLocale ?? .current
        )
    }
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationInteractorOutputProtocol {
    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            if stashItem == nil {
                wireframe.close(view: view)
            }
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveStashAccount(result: Result<MetaChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            stashAccountItem = accountItem
            updateView()
        case let .failure(error):
            logger?.error("Did receive stash account error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: assetInfo.assetPrecision)
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: assetInfo.assetPrecision
                )
            } else {
                balance = nil
            }
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didConfirmed(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case let .failure(error):
            if error.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else if error.isHardwareWalletSigningCancelled {
                return
            } else {
                wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
            }
        }
    }
}
