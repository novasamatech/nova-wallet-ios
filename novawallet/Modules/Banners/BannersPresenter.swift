import Foundation
import Foundation_iOS
import UIKit

final class BannersPresenter {
    weak var view: BannersViewProtocol?
    weak var moduleOutput: BannersModuleOutputProtocol?
    var locale: Locale

    private let wireframe: BannersWireframeProtocol
    private let interactor: BannersInteractorInputProtocol
    private let viewModelFactory: BannerViewModelFactoryProtocol
    let domain: Banners.Domain

    private let closeActionAvailable: Bool

    private var banners: [Banner]?
    private var closedBanners: ClosedBanners?
    private var localizedResources: BannersLocalizedResources?
    private var setUp: Bool = false

    private var resolvedContent: (banners: [Banner], closed: ClosedBanners, resources: BannersLocalizedResources)? {
        guard let banners, let closedBanners, let localizedResources else {
            guard domain == .assets, BittensorLocalBanner.chainAsset() != nil else { return nil }
            return ([BittensorLocalBanner.banner()], ClosedBanners(), [
                BittensorLocalBanner.id: BittensorLocalBanner.resource(for: locale)
            ])
        }

        guard domain == .assets, BittensorLocalBanner.chainAsset() != nil else {
            return (banners, closedBanners, localizedResources)
        }

        var resources = localizedResources
        resources[BittensorLocalBanner.id] = BittensorLocalBanner.resource(for: locale)
        var visibleClosedBanners = closedBanners
        visibleClosedBanners.remove(BittensorLocalBanner.id)
        return ([BittensorLocalBanner.banner()] + banners, visibleClosedBanners, resources)
    }

    init(
        interactor: BannersInteractorInputProtocol,
        wireframe: BannersWireframeProtocol,
        viewModelFactory: BannerViewModelFactoryProtocol,
        domain: Banners.Domain,
        locale: Locale,
        closeActionAvailable: Bool
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.domain = domain
        self.locale = locale
        self.closeActionAvailable = closeActionAvailable
    }

    private func provideBanners() {
        let content = resolvedContent
        let viewModel = viewModelFactory.createLoadableWidgetViewModel(
            for: content?.banners,
            closedBanners: content?.closed,
            closeAvailable: closeActionAvailable,
            localizedResources: content?.resources
        )

        view?.update(with: viewModel)
    }
}

// MARK: BannersPresenterProtocol

extension BannersPresenter: BannersPresenterProtocol {
    func setup(with availableTextWidth: CGFloat) {
        guard !setUp, availableTextWidth > 0 else { return }

        provideBanners()

        interactor.setup(
            with: locale,
            availableTextWidth: availableTextWidth
        )
        setUp = true
    }

    func action(for bannerId: String) {
        if bannerId == BittensorLocalBanner.id {
            wireframe.showBittensorEarn(from: view)
            return
        }

        guard
            let banner = banners?.first(where: { $0.id == bannerId }),
            let actionLink = banner.actionLink
        else {
            return
        }

        trackBannerClicked(with: banner.id)

        wireframe.openActionLink(urlString: actionLink)
    }

    func closeBanner(with id: String) {
        interactor.closeBanner(with: id)
    }
}

// MARK: BannersInteractorOutputProtocol

extension BannersPresenter: BannersInteractorOutputProtocol {
    func didReceive(_ bannersFetchResult: BannersFetchResult) {
        banners = bannersFetchResult.banners
        closedBanners = bannersFetchResult.closedBanners
        localizedResources = bannersFetchResult.localizedResources

        provideBanners()

        moduleOutput?.didReceiveBanners(state: bannersState)
    }

    func didReceive(_ updatedLocalizedResources: BannersLocalizedResources?) {
        localizedResources = updatedLocalizedResources
        provideBanners()

        moduleOutput?.didUpdateContent(state: bannersState)
    }

    func didReceive(_ updatedClosedBanners: ClosedBanners) {
        closedBanners = updatedClosedBanners

        let content = resolvedContent

        guard let viewModel = viewModelFactory.createWidgetViewModel(
            for: content?.banners,
            closedBanners: content?.closed,
            closeAvailable: closeActionAvailable,
            localizedResources: content?.resources
        ) else {
            return
        }

        guard !viewModel.banners.isEmpty else {
            moduleOutput?.didReceiveBanners(state: bannersState)
            return
        }

        view?.didCloseBanner(updatedViewModel: viewModel)
    }

    func didReceive(_ error: any Error) {
        if domain == .assets, BittensorLocalBanner.chainAsset() != nil {
            provideBanners()
            moduleOutput?.didReceiveBanners(state: .available)
        } else {
            moduleOutput?.didReceive(error)
        }
    }
}

// MARK: BannersModuleInputProtocol

extension BannersPresenter: BannersModuleInputProtocol {
    var bannersState: BannersState {
        guard let content = resolvedContent else {
            return .loading
        }

        return content.banners
            .filter { !content.closed.contains($0.id) }
            .isEmpty
            ? .unavailable
            : .available
    }

    func refresh() {
        guard let availableTextWidth = view?.getAvailableTextWidth() else { return }

        interactor.refresh(
            for: locale,
            availableTextWidth: availableTextWidth
        )
    }

    func updateLocale(_ newLocale: Locale) {
        guard let availableTextWidth = view?.getAvailableTextWidth() else { return }

        locale = newLocale

        interactor.updateResources(
            for: newLocale,
            availableTextWidth: availableTextWidth
        )
    }
}

enum BittensorLocalBanner {
    static let id = "local-bittensor-earn"

    static func resource(for locale: Locale) -> BannersLocalizedResource {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        return BannersLocalizedResource(
            bannerId: id,
            title: strings.stakingSubtensorBannerTitle(),
            details: strings.stakingSubtensorBannerDetails(),
            estimatedHeight: 64
        )
    }

    static func chainAsset() -> ChainAsset? {
        let registry = ChainRegistryFacade.sharedRegistry
        guard let chain = registry.getChain(for: KnowChainId.bittensor) else {
            return nil
        }

        return chainAsset(for: chain)
    }

    static func chainAsset(for chain: ChainModel) -> ChainAsset? {
        guard let asset = chain.utilityAsset(), asset.hasSubtensorStaking else {
            return nil
        }

        return ChainAsset(chain: chain, asset: asset)
    }

    static func banner() -> Banner {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let background = renderer.image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        return Banner(
            id: id,
            background: background,
            image: UIImage(named: "bittensorBannerArt"),
            clipsToBounds: true,
            actionLink: nil
        )
    }
}
