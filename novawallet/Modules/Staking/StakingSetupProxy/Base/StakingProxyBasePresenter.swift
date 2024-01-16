import Foundation
import BigInt
import SoraFoundation

class StakingProxyBasePresenter: StakingSetupProxyBasePresenterProtocol {
    weak var baseView: StakingSetupProxyViewProtocol?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let dataValidatingFactory: ProxyDataValidatorFactoryProtocol

    private let interactor: StakingProxyBaseInteractorInputProtocol
    private let wireframe: StakingSetupProxyBaseWireframeProtocol
    private var assetBalance: AssetBalance?
    private var proxyDeposit: BigUInt?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var proxyAddress: String?
    private var currentDeposit: BigUInt?
    private var deposit: BigUInt?
    private var existensialDeposit: BigUInt?
    private var maxProxies: Int?
    private var proxy: ProxyDefinition?

    init(
        chainAsset: ChainAsset,
        interactor: StakingProxyBaseInteractorInputProtocol,
        wireframe: StakingSetupProxyBaseWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: ProxyDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.localizationManager = localizationManager
    }

    func provideProxyDeposit() {
        guard let amount = proxyDeposit?.decimal(precision: chainAsset.asset.precision) else {
            baseView?.didReceiveProxyDeposit(viewModel: .loading)
            return
        }
        let proxyDepositViewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: priceData
        ).value(for: selectedLocale)
        baseView?.didReceiveProxyDeposit(viewModel: .loaded(value: .init(
            isEditable: false,
            balanceViewModel: proxyDepositViewModel
        )))
    }

    func provideFee() {
        guard let fee = fee?.amount.decimal(precision: chainAsset.asset.precision) else {
            baseView?.didReceiveFee(viewModel: nil)
            return
        }
        let feeViewModel = balanceViewModelFactory.balanceFromPrice(
            fee,
            priceData: priceData
        ).value(for: selectedLocale)
        baseView?.didReceiveFee(viewModel: feeViewModel)
    }

    func updateView() {
        provideProxyDeposit()
        provideFee()
    }

    // MARK: - StakingSetupProxyPresenterProtocol

    func setup() {
        interactor.setup()
    }

    func showDepositInfo() {}

    func createCommonValidations() -> [DataValidating]? {
        [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.estimateFee()
            },
            dataValidatingFactory.canPayFeeInPlank(
                balance: assetBalance?.regularTransferrableBalance(),
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.proxyNotExists(
                address: proxyAddress ?? "",
                chain: chainAsset.chain,
                proxyList: proxy,
                locale: selectedLocale
            ),
            dataValidatingFactory.hasSufficientBalance(
                available: (assetBalance?.regularTransferrableBalance() ?? 0) + (currentDeposit ?? 0),
                deposit: deposit,
                fee: fee?.amountForCurrentAccount,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: fee?.amountForCurrentAccount,
                totalAmount: assetBalance?.freeInPlank,
                minimumBalance: existensialDeposit,
                locale: selectedLocale
            ),
            dataValidatingFactory.notReachedMaximimProxyCount(
                proxy?.definition.count ?? 0,
                limit: maxProxies ?? 32,
                chain: chainAsset.chain,
                locale: selectedLocale
            )
        ]
    }
}

extension StakingProxyBasePresenter: StakingProxyBaseInteractorOutputProtocol {
    func didReceive(baseError _: StakingProxyBaseError) {}
    func didReceive(proxyDeposit: BigUInt?) {
        self.proxyDeposit = proxyDeposit
        provideProxyDeposit()
    }

    func didReceive(assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceive(fee: ExtrinsicFeeProtocol?) {
        self.fee = fee
        provideFee()
    }

    func didReceive(price: PriceData?) {
        priceData = price
        provideProxyDeposit()
        provideFee()
    }

    func didReceiveAccount(_: MetaChainAccountResponse?, for _: AccountId) {}
}

extension StakingProxyBasePresenter: Localizable {
    func applyLocalization() {
        if baseView?.isSetup == true {
            updateView()
        }
    }
}
