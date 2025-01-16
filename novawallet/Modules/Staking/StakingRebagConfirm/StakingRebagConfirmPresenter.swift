import Foundation
import Foundation_iOS
import BigInt

final class StakingRebagConfirmPresenter {
    weak var view: StakingRebagConfirmViewProtocol?
    let wireframe: StakingRebagConfirmWireframeProtocol
    let interactor: StakingRebagConfirmInteractorInputProtocol
    let logger: LoggerProtocol?
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let displayFormatter: LocalizableResource<LocalizableDecimalFormatting>
    let tokenFormatter: LocalizableResource<TokenFormatter>
    let balanceViewModelFactory: BalanceViewModelFactory
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private var fee: ExtrinsicFeeProtocol?
    private var price: PriceData?
    private var balance: AssetBalance?
    private var networkInfo: NetworkStakingInfo?
    private var currentBagListNode: BagList.Node?
    private var ledgerInfo: StakingLedger?
    private var totalIssuance: BigUInt?
    private var stashItem: StashItem?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        interactor: StakingRebagConfirmInteractorInputProtocol,
        wireframe: StakingRebagConfirmWireframeProtocol,
        displayFormatter: LocalizableResource<LocalizableDecimalFormatting>,
        tokenFormatter: LocalizableResource<TokenFormatter>,
        balanceViewModelFactory: BalanceViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.displayFormatter = displayFormatter
        self.tokenFormatter = tokenFormatter
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func provideFeeViewModel() {
        guard let fee = fee,
              let feeDecimal = Decimal.fromSubstrateAmount(
                  fee.amount,
                  precision: chainAsset.assetDisplayInfo.assetPrecision
              ) else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    private func provideHintsViewModel() {
        let hint = R.string.localizable.stakingRebagAlertMessage(
            preferredLanguages: selectedLocale.rLanguages
        )
        view?.didReceiveHints(viewModel: [
            hint
        ])
    }

    private func provideCurrentBagListViewModel() {
        guard let networkInfo = networkInfo,
              let currentBagListNode = currentBagListNode,
              let totalIssuance = totalIssuance else {
            return
        }
        let bag = networkInfo.searchBounds(for: currentBagListNode, totalIssuance: totalIssuance)
        let viewModel = createAnyBagViewModel(bagListBounds: bag)

        view?.didReceiveCurrentRebag(viewModel: viewModel)
    }

    private func provideNewBagListViewModel() {
        guard let ledgerInfo = ledgerInfo,
              let totalIssuance = totalIssuance,
              let networkInfo = networkInfo else {
            return
        }

        let bag = networkInfo.searchBounds(ledgerInfo: ledgerInfo, totalIssuance: totalIssuance)
        let viewModel = createAnyBagViewModel(bagListBounds: bag)
        view?.didReceiveNextRebag(viewModel: viewModel)
    }

    private func createAnyBagViewModel(bagListBounds: BagListBounds?) -> String {
        guard let bagListBounds = bagListBounds else {
            return ""
        }
        guard let lowerBoundDecimal = convertPlanksToDecimal(bagListBounds.lower),
              let upperBoundDecimal = convertPlanksToDecimal(bagListBounds.upper) else {
            return ""
        }

        let formattedLowerBound = displayFormatter
            .value(for: selectedLocale)
            .stringFromDecimal(lowerBoundDecimal)
        let formattedUpperBound = tokenFormatter
            .value(for: selectedLocale)
            .stringFromDecimal(upperBoundDecimal)

        return [formattedLowerBound, formattedUpperBound]
            .compactMap { $0 }
            .joined(separator: "—")
    }

    private func provideConfirmState() {
        let isAvailable = stashItem != nil
        view?.didReceiveConfirmState(isAvailable: isAvailable)
    }

    private func convertPlanksToDecimal(_ value: BigUInt) -> Decimal? {
        Decimal.fromSubstrateAmount(
            value,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )
    }

    private func refreshFeeIfNeeded() {
        guard fee == nil, let stashItem = stashItem else {
            return
        }

        interactor.refreshFee(stashItem: stashItem)
    }
}

extension StakingRebagConfirmPresenter: StakingRebagConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
        provideWalletViewModel()
        provideAccountViewModel()
        provideHintsViewModel()
        provideConfirmState()
        provideFeeViewModel()
    }

    func confirm() {
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in
                    self?.refreshFeeIfNeeded()
                }
            ),

            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let stashItem = self?.stashItem else {
                return
            }
            self?.view?.didStartLoading()
            self?.interactor.submit(stashItem: stashItem)
        }
    }

    func selectAccount() {
        let accountId = selectedAccount.chainAccount.accountId
        let chainFormat = chainAsset.chain.chainFormat

        guard let view = view,
              let address = try? accountId.toAddress(using: chainFormat) else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

extension StakingRebagConfirmPresenter: StakingRebagConfirmInteractorOutputProtocol {
    func didReceive(networkInfo: NetworkStakingInfo?) {
        self.networkInfo = networkInfo
        provideCurrentBagListViewModel()
        provideNewBagListViewModel()
    }

    func didReceive(currentBagListNode: BagList.Node?) {
        self.currentBagListNode = currentBagListNode
        provideCurrentBagListViewModel()
    }

    func didReceive(ledgerInfo: StakingLedger?) {
        self.ledgerInfo = ledgerInfo
        provideNewBagListViewModel()
    }

    func didReceive(totalIssuance: BigUInt?) {
        self.totalIssuance = totalIssuance
        provideNewBagListViewModel()
    }

    func didReceive(fee: ExtrinsicFeeProtocol) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(price: PriceData?) {
        self.price = price
        provideFeeViewModel()
    }

    func didReceive(assetBalance: AssetBalance?) {
        balance = assetBalance
    }

    func didReceive(error: StakingRebagConfirmError) {
        logger?.error(error.localizedDescription)

        guard let view = view else {
            return
        }
        view.didStopLoading()

        switch error {
        case .fetchPriceFailed,
             .fetchBagListScoreFactorFailed,
             .fetchBagListNodeFailed,
             .fetchLedgerInfoFailed,
             .fetchBalanceFailed,
             .fetchStashItemFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .cantResolveModuleName:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryModuleName()
            }
        case .fetchNetworkInfoFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryNetworkInfo()
            }
        case .fetchFeeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                if let stashItem = self?.stashItem {
                    self?.interactor.refreshFee(stashItem: stashItem)
                }
            }
        case let .submitFailed(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceive(stashItem: StashItem?) {
        self.stashItem = stashItem
        provideConfirmState()
    }

    func didSubmitRebag() {
        view?.didStopLoading()
        wireframe.complete(from: view, locale: selectedLocale)
    }
}

extension StakingRebagConfirmPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideFeeViewModel()
            provideHintsViewModel()
            provideCurrentBagListViewModel()
            provideNewBagListViewModel()
        }
    }
}
