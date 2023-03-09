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

    private var fee: BigUInt?
    private var price: PriceData?
    private var balance: AssetBalance?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        interactor: StakingRebagConfirmInteractorInputProtocol,
        wireframe: StakingRebagConfirmWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
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
}

extension StakingRebagConfirmPresenter: StakingRebagConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
        provideAccountViewModel()
        provideHintsViewModel()
    }

    func confirm() {}

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
    func didReceive(currentBag: (lowerBound: BigUInt, upperBound: BigUInt)) {
        guard let lowerBoundDecimal = convertPlanksToDecimal(currentBag.lowerBound),
              let upperBoundDecimal = convertPlanksToDecimal(currentBag.upperBound) else {
            return
        }

        let viewModel = "\(lowerBoundDecimal)-\(upperBoundDecimal) \(chainAsset.assetDisplayInfo.symbol)"
        view?.didReceiveCurrentRebag(viewModel: viewModel)
    }

    func didReceive(nextBag: (lowerBound: BigUInt, upperBound: BigUInt)) {
        guard let lowerBoundDecimal = convertPlanksToDecimal(nextBag.lowerBound),
              let upperBoundDecimal = convertPlanksToDecimal(nextBag.upperBound) else {
            return
        }

        let viewModel = "\(lowerBoundDecimal)-\(upperBoundDecimal) \(chainAsset.assetDisplayInfo.symbol)"
        view?.didReceiveNextRebag(viewModel: viewModel)
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
    }

    func didSubmitRebag() {}
}

extension StakingRebagConfirmPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
