import Foundation
import BigInt
import Foundation_iOS

class StakingProxyBasePresenter: StakingSetupProxyBasePresenterProtocol {
    weak var baseView: StakingSetupProxyBaseViewProtocol?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let dataValidatingFactory: ProxyDataValidatorFactoryProtocol
    let wallet: MetaAccountModel

    private let interactor: StakingProxyBaseInteractorInputProtocol
    private let wireframe: StakingSetupProxyBaseWireframeProtocol
    private(set) var assetBalance: AssetBalance?
    private(set) var proxyDeposit: ProxyDeposit?
    private(set) var priceData: PriceData?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var existensialDeposit: BigUInt?
    private(set) var maxProxies: Int?
    private(set) var proxy: UncertainStorage<ProxyDefinition?> = .undefined

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        interactor: StakingProxyBaseInteractorInputProtocol,
        wireframe: StakingSetupProxyBaseWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: ProxyDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.localizationManager = localizationManager
    }

    func provideProxyDeposit() {
        guard let amount = proxyDeposit?.diff.decimal(precision: chainAsset.asset.precision) else {
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

    func showDepositInfo() {
        wireframe.showProxyDepositInfo(from: baseView)
    }

    func createValidations() -> [DataValidating] {
        [
            dataValidatingFactory.validAddress(
                getProxyAddress(),
                chain: chainAsset.chain,
                locale: selectedLocale
            ),
            dataValidatingFactory.notSelfDelegating(
                selfId: getAccountId(),
                delegateId: getProxyAccountId(),
                locale: selectedLocale
            ),
            dataValidatingFactory.proxyNotExists(
                address: getProxyAddress(),
                chain: chainAsset.chain,
                proxyList: proxy.map { $0?.definition ?? [] }.value,
                locale: selectedLocale
            ),
            dataValidatingFactory.notReachedMaximimProxyCount(
                proxy.map { $0?.definition.count ?? 0 }.value.map { $0 + 1 },
                limit: maxProxies,
                chain: chainAsset.chain,
                locale: selectedLocale
            ),
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
            dataValidatingFactory.hasSufficientBalance(
                available: (assetBalance?.regularTransferrableBalance() ?? 0) + (proxyDeposit?.current ?? 0),
                deposit: proxyDeposit?.new,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: fee?.amountForCurrentAccount ?? 0,
                totalAmount: assetBalance?.freeInPlank,
                minimumBalance: existensialDeposit,
                locale: selectedLocale
            )
        ]
    }

    func getProxyAddress() -> AccountAddress {
        fatalError("This function should be overriden")
    }

    func getProxyAccountId() -> AccountId? {
        let address = getProxyAddress()
        return try? address.toAccountId(using: chainAsset.chain.chainFormat)
    }

    func getAccountId() -> AccountId? {
        let request = chainAsset.chain.accountRequest()
        return wallet.fetch(for: request)?.accountId
    }
}

extension StakingProxyBasePresenter: StakingProxyBaseInteractorOutputProtocol {
    func didReceive(baseError: StakingProxyBaseError) {
        switch baseError {
        case .fetchDepositBase, .fetchDepositFactor, .fetchED, .fetchMaxProxyCount:
            wireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.interactor.refetchConstants()
            }
        case .handleProxies, .balance, .price:
            wireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .fee:
            wireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.interactor.estimateFee()
            }
        }
    }

    func didReceive(proxyDeposit: ProxyDeposit?) {
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

    func didReceive(maxProxies: Int?) {
        self.maxProxies = maxProxies
    }

    func didReceive(existensialDeposit: BigUInt?) {
        self.existensialDeposit = existensialDeposit
    }

    func didReceive(proxy: ProxyDefinition?) {
        self.proxy = .defined(proxy)
    }

    func didReceive(price: PriceData?) {
        priceData = price
        provideProxyDeposit()
        provideFee()
    }
}

extension StakingProxyBasePresenter: Localizable {
    func applyLocalization() {
        if baseView?.isSetup == true {
            updateView()
        }
    }
}
