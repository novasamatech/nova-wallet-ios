import Foundation
import SoraFoundation
import BigInt

final class StartStakingInfoPresenter {
    weak var view: StartStakingInfoViewProtocol?
    let wireframe: StartStakingInfoWireframeProtocol
    let interactor: StartStakingInfoInteractorInputProtocol
    let startStakingViewModelFactory: StartStakingViewModelFactoryProtocol
    let dashboardItem: Multistaking.DashboardItem

    private var assetBalance: AssetBalance?
    private var price: PriceData?
    private var chainAsset: ChainAsset?
    private var minStake: LoadableViewModelState<BigUInt?> = .loading
    private var eraTime: LoadableViewModelState<TimeInterval?> = .loading
    private var unstakingPeriod: LoadableViewModelState<TimeInterval> = .loading
    private var nominationEra: LoadableViewModelState<TimeInterval> = .loading

    var allDataLoaded: Bool {
        !minStake.isLoading && !eraTime.isLoading && !unstakingPeriod.isLoading && !nominationEra.isLoading
    }

    init(
        interactor: StartStakingInfoInteractorInputProtocol,
        dashboardItem: Multistaking.DashboardItem,
        wireframe: StartStakingInfoWireframeProtocol,
        startStakingViewModelFactory: StartStakingViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.dashboardItem = dashboardItem
        self.wireframe = wireframe
        self.startStakingViewModelFactory = startStakingViewModelFactory
    }
}

extension StartStakingInfoPresenter: StartStakingInfoPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    private func provideViewModel() {
        guard allDataLoaded,
              let chainAsset = chainAsset,
              let eraTime = eraTime.value,
              let eraDuration = eraTime,
              let unstakePeriod = unstakingPeriod.value,
              let nominationEraValue = nominationEra.value else {
            return
        }

        let maxApy = dashboardItem.maxApy
        let title = startStakingViewModelFactory.earnupModel(
            earnings: maxApy,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        let wikiUrl = startStakingViewModelFactory.wikiModel(
            locale: selectedLocale,
            url: URL(string: "https://novawallet.io")!
        )
        let termsUrl = startStakingViewModelFactory.termsModel(
            locale: selectedLocale,
            url: URL(string: "https://novawallet.io")!
        )

        let paragraphs = [
            startStakingViewModelFactory.stakeModel(
                minStake: minStake.value ?? nil,
                nextEra: nominationEraValue,
                chainAsset: chainAsset,
                locale: selectedLocale
            ),
            startStakingViewModelFactory.unstakeModel(unstakePeriod: unstakePeriod, locale: selectedLocale),
            startStakingViewModelFactory.rewardModel(eraDuration: eraDuration, locale: selectedLocale),
            startStakingViewModelFactory.govModel(locale: selectedLocale),
            startStakingViewModelFactory.recommendationModel(locale: selectedLocale)
        ]
        let stubModel = StartStakingViewModel(
            title: title,
            paragraphs: paragraphs,
            wikiUrl: wikiUrl,
            termsUrl: termsUrl
        )
        view?.didReceive(viewModel: .loaded(value: stubModel))
    }

    private func provideBalanceModel() {
        guard let chainAsset = chainAsset else {
            return
        }
        let viewModel = startStakingViewModelFactory.balance(
            amount: assetBalance?.freeInPlank,
            priceData: price,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        view?.didReceive(balance: viewModel)
    }
}

extension StartStakingInfoPresenter: StartStakingInfoInteractorOutputProtocol {
    func didReceiveChainAsset(_ chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        provideBalanceModel()
    }

    func didReceiveAccount(_: MetaChainAccountResponse?) {}

    func didReceivePrice(_ price: PriceData?) {
        self.price = price
        provideBalanceModel()
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
        provideBalanceModel()
    }

    func didReceiveError(_: StartStakingInfoError) {}

    func didReceiveMinStake(_ minStake: BigUInt?) {
        self.minStake = .loaded(value: minStake)
        provideViewModel()
    }

    func didReceiveEraTime(_ time: TimeInterval?) {
        eraTime = .loaded(value: time)
        provideViewModel()
    }

    func didReceive(unstakingPeriod: TimeInterval) {
        self.unstakingPeriod = .loaded(value: unstakingPeriod)
        provideViewModel()
    }

    func didReceiveNextEraTime(_ time: TimeInterval) {
        nominationEra = .loaded(value: time)
        provideViewModel()
    }
}

extension StartStakingInfoPresenter: Localizable {
    func applyLocalization() {}
}
