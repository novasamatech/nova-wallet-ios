import Foundation
import Foundation_iOS
import Operation_iOS

final class GiftListPresenter {
    weak var view: GiftListViewProtocol?
    let wireframe: GiftListWireframeProtocol
    let interactor: GiftListInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    let onboardingViewModelFactory: GiftsOnboardingViewModelFactoryProtocol
    let giftListViewModelFactory: GiftListViewModelFactoryProtocol

    let learnMoreUrl: URL

    var gifts: [GiftModel.Id: GiftModel] = [:]
    var chainAssets: [ChainAssetId: ChainAsset] = [:]

    init(
        interactor: GiftListInteractorInputProtocol,
        wireframe: GiftListWireframeProtocol,
        onboardingViewModelFactory: GiftsOnboardingViewModelFactoryProtocol,
        giftListViewModelFactory: GiftListViewModelFactoryProtocol,
        learnMoreUrl: URL,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.onboardingViewModelFactory = onboardingViewModelFactory
        self.giftListViewModelFactory = giftListViewModelFactory
        self.learnMoreUrl = learnMoreUrl
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftListPresenter {
    func provideOnboarding() {
        let viewModel = onboardingViewModelFactory.createViewModel(
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }

    func provideGiftList() {
        let sections = giftListViewModelFactory.createViewModel(
            for: Array(gifts.values),
            chainAssets: chainAssets,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(listSections: sections)
    }
}

// MARK: - GiftListPresenterProtocol

extension GiftListPresenter: GiftListPresenterProtocol {
    func selectGift(with identifier: String) {
        guard
            let gift = gifts[identifier],
            let chainAsset = chainAssets[gift.chainAssetId]
        else { return }

        wireframe.showGift(
            gift,
            chainAsset: chainAsset,
            from: view
        )
    }

    func setup() {
        view?.didReceive(loading: true)
        interactor.setup()
    }

    func activateLearnMore() {
        guard let view else { return }

        wireframe.showWeb(
            url: learnMoreUrl,
            from: view,
            style: .automatic
        )
    }

    func actionCreateGift() {
        wireframe.showCreateGift(from: view)
    }
}

// MARK: - GiftListInteractorOutputProtocol

extension GiftListPresenter: GiftListInteractorOutputProtocol {
    func didReceive(
        _ changes: [DataProviderChange<GiftModel>],
        _ chainAssets: [ChainAssetId: ChainAsset]
    ) {
        gifts = changes.mergeToDict(gifts)
        self.chainAssets = chainAssets

        guard !gifts.isEmpty else {
            provideOnboarding()
            return
        }

        provideGiftList()
    }

    func didReceive(_: any Error) {
        view?.didReceive(loading: false)

        wireframe.presentRequestStatus(
            on: view,
            locale: localizationManager.selectedLocale,
            retryAction: { [weak self] in
                self?.interactor.setup()
            }
        )
    }
}
