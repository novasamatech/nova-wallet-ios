import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol

    var viewModels: [BannerViewModel]?
    var loopedViewModels: [BannerViewModel]?

    var scrollCompletionHandler: (() -> Void)?

    private var staticState: StaticState?
    private var dynamicState: DynamicState?

    init(presenter: BannersPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BannersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        setupActions()
        presenter.setup()
    }
}

// MARK: Private

private extension BannersViewController {
    func setupCollectionView() {
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.registerCellClass(BannerCollectionViewCell.self)
    }

    func setupActions() {
        rootView.closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    func setup(with widgetModel: BannersWidgetviewModel) {
        setupPageControl(for: widgetModel.banners)
        setupBannersCollection(with: widgetModel.banners)

        rootView.setBackgroundImage(widgetModel.banners.first?.backgroundImage)
        rootView.setCloseButton(available: widgetModel.showsCloseButton)
    }

    func setupPageControl(for banners: [BannerViewModel]) {
        if banners.count > 1 {
            rootView.pageControl.numberOfPages = banners.count
            rootView.pageControl.show()
        } else {
            rootView.pageControl.hide()
        }
    }

    func setupBannersCollection(with viewModels: [BannerViewModel]) {
        setViewModels(viewModels)

        let multipleBanners: Bool = viewModels.count > 1
        let itemIndex = multipleBanners ? 1 : 0

        staticState = .init(
            currentPage: 0,
            pageByActualOffset: itemIndex
        )

        rootView.collectionView.reloadData { [weak self] in
            self?.scrollToItem(
                index: itemIndex,
                animated: true
            ) {
                self?.rootView.collectionView.alwaysBounceHorizontal = multipleBanners
            }
        }
    }

    func scrollToItem(
        index: Int,
        animated: Bool,
        scrollCompletionHandler: (() -> Void)? = nil
    ) {
        guard let staticState else { return }

        let indexPath = IndexPath(item: index, section: 0)

        if animated {
            dynamicState = DynamicState(
                contentOffset: rootView.collectionView.contentOffset.x,
                pageWidth: rootView.collectionView.bounds.width,
                currentPage: staticState.currentPage
            )
        }

        self.scrollCompletionHandler = scrollCompletionHandler

        rootView.collectionView.scrollTo(
            horizontalPage: index,
            animated: animated
        )
        rootView.collectionView.setNeedsLayout()
    }

    func setViewModels(_ viewModels: [BannerViewModel]) {
        self.viewModels = viewModels

        guard
            viewModels.count > 1,
            let first = viewModels.first,
            let last = viewModels.last
        else {
            loopedViewModels = nil

            return
        }

        loopedViewModels = viewModels

        loopedViewModels?.insert(last, at: 0)
        loopedViewModels?.append(first)
    }

    func calculateTransitionProgress(
        for newDynamicState: DynamicState,
        _ oldDynamicState: DynamicState
    ) -> CGFloat {
        guard let staticState, let viewModels else { return .zero }

        let scrollingForward: Bool = oldDynamicState.contentOffset < newDynamicState.contentOffset

        let roundedPageIndex = newDynamicState.rawPageIndex.rounded(.down)
        let rawProgress = abs(
            (newDynamicState.contentOffset - roundedPageIndex * newDynamicState.pageWidth) / newDynamicState.pageWidth
        )

        let draggedToNext = (
            scrollingForward &&
                newDynamicState.rawPageIndex > CGFloat(staticState.pageByActualOffset)
        )
        let draggedToPrevious = (
            !scrollingForward &&
                newDynamicState.rawPageIndex < CGFloat(staticState.pageByActualOffset)
        )
        let changesPage: Bool = draggedToNext
            || draggedToPrevious

        return if changesPage {
            scrollingForward
                ? (rawProgress == 0 ? 1.0 : rawProgress)
                : (1 - rawProgress)
        } else {
            scrollingForward
                ? (rawProgress == 0 ? rawProgress : 1 - rawProgress)
                : rawProgress
        }
    }

    func calculateTargetPageIndex(
        using dynamicState: DynamicState,
        staticState: StaticState
    ) -> Int {
        let rawPageIndex = dynamicState.rawPageIndex

        let targetPageIndex = if CGFloat(staticState.pageByActualOffset) == rawPageIndex {
            staticState.pageByActualOffset
        } else if rawPageIndex - CGFloat(staticState.pageByActualOffset) > 1 {
            Int(floor(rawPageIndex))
        } else {
            staticState.pageByActualOffset + (rawPageIndex > CGFloat(staticState.pageByActualOffset) ? 1 : -1)
        }

        return targetPageIndex
    }

    func calculateIndicatorPageIndex(basedOn targetPageIndex: Int) -> Int {
        guard
            let viewModels,
            let loopedViewModels,
            let dynamicState,
            dynamicState.rawPageIndex.rounded(.up) != dynamicState.rawPageIndex.rounded(.down)
        else { return rootView.pageControl.currentPage }

        return if targetPageIndex == 0 {
            viewModels.count - 1
        } else if targetPageIndex == loopedViewModels.count - 1 {
            0
        } else {
            targetPageIndex - 1
        }
    }

    func updateBackground(
        for newDynamicState: DynamicState,
        oldDynamicState: DynamicState,
        targetPageIndex: Int
    ) {
        guard let viewModels = loopedViewModels else { return }

        let progress = calculateTransitionProgress(
            for: newDynamicState,
            oldDynamicState
        )

        let backgroundImage = viewModels[targetPageIndex].backgroundImage

        rootView.backgroundView.changeBackground(
            to: backgroundImage,
            progress: progress
        )
    }

    func changeCurrentOffsetIfNeeded(for scrollView: UIScrollView) {
        guard let viewModels = loopedViewModels else {
            return
        }

        let itemWidth = scrollView.bounds.width
        let fullContentWidth = itemWidth * CGFloat(viewModels.count)

        let trailingLoopingOffset: CGFloat = fullContentWidth - itemWidth
        let leadingLoopingOffset: CGFloat = 0

        if scrollView.contentOffset.x == leadingLoopingOffset {
            scrollView.contentOffset.x = trailingLoopingOffset - itemWidth
        } else if scrollView.contentOffset.x == trailingLoopingOffset {
            scrollView.contentOffset.x = leadingLoopingOffset + itemWidth
        }
    }

    // MARK: Actions

    @objc func actionClose() {
        guard
            let viewModels,
            let staticState
        else { return }

        let actualViewModels = if let loopedViewModels {
            loopedViewModels
        } else {
            viewModels
        }

        guard staticState.pageByActualOffset < actualViewModels.count else {
            return
        }

        let banner = actualViewModels[staticState.pageByActualOffset]

        presenter.closeBanner(with: banner.id)
    }
}

// MARK: BannersViewProtocol

extension BannersViewController: BannersViewProtocol {
    func update(with viewModel: LoadableViewModelState<BannersWidgetviewModel>?) {
        switch viewModel {
        case let .cached(model), let .loaded(model):
            setup(with: model)
            rootView.setLoaded()
        case .loading, .none:
            viewModels = nil
            rootView.setLoading()
        }
    }

    func didCloseBanner(updatedViewModel: BannersWidgetviewModel) {
        guard let staticState else { return }

        let nextItemIndex: Int

        if let loopedViewModels, staticState.pageByActualOffset < loopedViewModels.count - 1 {
            nextItemIndex = staticState.pageByActualOffset + 1
        } else {
            nextItemIndex = 0
        }

        scrollToItem(
            index: nextItemIndex,
            animated: true
        ) { [weak self] in
            guard let self else { return }
            setViewModels(updatedViewModel.banners)
            setupPageControl(for: updatedViewModel.banners)

            let newPageByActualOffset = nextItemIndex - 1

            self.staticState = .init(
                currentPage: staticState.currentPage - 1,
                pageByActualOffset: newPageByActualOffset
            )

            let pageWidth = rootView.collectionView.bounds.width

            rootView.collectionView.reloadData()
            rootView.collectionView.contentOffset.x = CGFloat(newPageByActualOffset) * pageWidth

            rootView.collectionView.alwaysBounceHorizontal = updatedViewModel.banners.count > 1
        }
    }
}

// MARK: UIScrollViewDelegate

extension BannersViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let staticState, let dynamicState else { return }

        let newDynamicState = DynamicState(
            contentOffset: scrollView.contentOffset.x,
            pageWidth: scrollView.bounds.width,
            currentPage: staticState.currentPage
        )

        let targetPageIndex = calculateTargetPageIndex(
            using: newDynamicState,
            staticState: staticState
        )
        let indicatorPageIndex = calculateIndicatorPageIndex(basedOn: targetPageIndex)

        rootView.pageControl.currentPage = indicatorPageIndex

        updateBackground(
            for: newDynamicState,
            oldDynamicState: dynamicState,
            targetPageIndex: targetPageIndex
        )

        self.dynamicState = newDynamicState
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let staticState else { return }

        let dynamicState = DynamicState(
            contentOffset: scrollView.contentOffset.x,
            pageWidth: scrollView.bounds.width,
            currentPage: staticState.currentPage
        )

        self.dynamicState = dynamicState
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollViewDidEndDecelerating(scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let viewModels else { return }

        let pageByOffsetBeforeChanges = Int(
            round(scrollView.contentOffset.x / scrollView.bounds.width)
        )

        let currentPage = pageByOffsetBeforeChanges % viewModels.count

        changeCurrentOffsetIfNeeded(for: scrollView)

        let pageByOffsetAfterChanges = Int(
            round(scrollView.contentOffset.x / scrollView.bounds.width)
        )

        staticState = StaticState(
            currentPage: currentPage,
            pageByActualOffset: pageByOffsetAfterChanges
        )

        scrollCompletionHandler?()

        scrollCompletionHandler = nil
        dynamicState = nil
    }
}
