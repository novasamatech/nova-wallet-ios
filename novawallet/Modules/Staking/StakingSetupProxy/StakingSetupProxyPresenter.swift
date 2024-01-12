import Foundation
import BigInt
import SoraFoundation

final class StakingSetupProxyPresenter {
    weak var view: StakingSetupProxyViewProtocol?
    let wireframe: StakingSetupProxyWireframeProtocol
    let interactor: StakingSetupProxyInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAsset: ChainAsset
    private var assetBalance: AssetBalance?
    private var proxyDeposit: BigUInt?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?

    init(
        chainAsset: ChainAsset,
        interactor: StakingSetupProxyInteractorInputProtocol,
        wireframe: StakingSetupProxyWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideProxyDeposit() {
        guard let amount = proxyDeposit?.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveProxyDeposit(viewModel: .loading)
            return
        }
        let proxyDepositViewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: priceData
        ).value(for: selectedLocale)
        view?.didReceiveProxyDeposit(viewModel: .loaded(value: .init(
            isEditable: false,
            balanceViewModel: proxyDepositViewModel
        )))
    }

    private func provideFee() {
        guard let fee = fee?.amount.decimal(precision: chainAsset.asset.precision) else {
            view?.didReceiveFee(viewModel: nil)
            return
        }
        let feeViewModel = balanceViewModelFactory.balanceFromPrice(
            fee,
            priceData: priceData
        ).value(for: selectedLocale)
        view?.didReceiveFee(viewModel: feeViewModel)
    }

    private func updateView() {
        provideProxyDeposit()
        provideFee()
    }
}

extension StakingSetupProxyPresenter: StakingSetupProxyPresenterProtocol {
    func setup() {
        view?.didReceive(token: chainAsset.assetDisplayInfo.symbol)
        interactor.setup()
    }

    func complete(authority _: String) {}
    func showDepositInfo() {}
}

extension StakingSetupProxyPresenter: StakingSetupProxyInteractorOutputProtocol {
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

extension StakingSetupProxyPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
