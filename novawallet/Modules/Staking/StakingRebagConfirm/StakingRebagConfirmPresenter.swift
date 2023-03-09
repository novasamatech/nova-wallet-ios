import Foundation
import SoraFoundation
import BigInt

final class StakingRebagConfirmPresenter {
    weak var view: StakingRebagConfirmViewProtocol?
    let wireframe: StakingRebagConfirmWireframeProtocol
    let interactor: StakingRebagConfirmInteractorInputProtocol
    let logger: LoggerProtocol?
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private var fee: BigUInt?
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
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol?
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
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
                  fee,
                  precision: chainAsset.assetDisplayInfo.assetPrecision
              ) else {
            return
        }

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveNetworkFee(viewModel: viewModel)
    }

    // TODO: Lokalize
    private func provideHintsViewModel() {
        let hint = "Having outdated position in the queue of stake assignment to a validator may suspend your rewards"
        view?.didReceiveHints(viewModel: [
            hint
        ])
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

    private func provideCurrentBagList() {
        guard let networkInfo = networkInfo, let currentBagListNode = currentBagListNode else {
            return
        }
        let bag = networkInfo.searchBounds(for: currentBagListNode)
        let viewModel = createViewModel(bagListBounds: bag)

        view?.didReceiveCurrentRebag(viewModel: viewModel)
    }

    private func provideNextBagList() {
        guard let ledgerInfo = ledgerInfo,
              let totalIssuance = totalIssuance,
              let networkInfo = networkInfo else {
            return
        }

        let bag = networkInfo.searchBounds(ledgerInfo: ledgerInfo, totalIssuance: totalIssuance)
        let viewModel = createViewModel(bagListBounds: bag)
        view?.didReceiveNextRebag(viewModel: viewModel)
    }

    private func createViewModel(bagListBounds: BagListBounds?) -> String {
        guard let bagListBounds = bagListBounds else {
            return ""
        }
        guard let lowerBoundDecimal = convertPlanksToDecimal(bagListBounds.lower),
              let upperBoundDecimal = convertPlanksToDecimal(bagListBounds.upper) else {
            return ""
        }

        return "\(lowerBoundDecimal)-\(upperBoundDecimal) \(chainAsset.assetDisplayInfo.symbol)"
    }

    private func provideConfirmState() {
        let isAvailable = stashItem != nil
        view?.didReceiveConfirmState(isAvailable: isAvailable)
    }
}

extension StakingRebagConfirmPresenter: StakingRebagConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
        provideAccountViewModel()
        provideHintsViewModel()
        provideConfirmState()
    }

    func confirm() {
        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: chainAsset.assetDisplayInfo.assetPrecision,
                onError: { [weak self] in
                    self?.refreshFeeIfNeeded()
                }
            ),

            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.freeInPlank,
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
        guard let view = view,
              let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chainAsset.chain.chainFormat) else {
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
        provideCurrentBagList()
        provideNextBagList()
    }

    func didReceive(currentBagListNode: BagList.Node?) {
        self.currentBagListNode = currentBagListNode
        provideCurrentBagList()
    }

    func didReceive(ledgerInfo: StakingLedger?) {
        self.ledgerInfo = ledgerInfo
        provideNextBagList()
    }

    func didReceive(totalIssuance: BigUInt?) {
        self.totalIssuance = totalIssuance
        provideNextBagList()
    }

    func didReceive(fee: BigUInt?) {
        self.fee = fee
        provideFeeViewModel()
    }

    func didReceive(price: PriceData?) {
        self.price = price
        provideFeeViewModel()
    }

    func didReceive(assetBalance: AssetBalance?) {
        balance = assetBalance
        provideWalletViewModel()
    }

    func didReceive(error: StakingRebagConfirmError) {
        logger?.error(error.localizedDescription)
        view?.didStopLoading()
    }

    func didReceive(stashItem: StashItem?) {
        self.stashItem = stashItem
        provideConfirmState()
    }

    func didSubmitRebag() {
        view?.didStopLoading()
    }
}

extension StakingRebagConfirmPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
