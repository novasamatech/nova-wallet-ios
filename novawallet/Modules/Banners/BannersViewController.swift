import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol

    var viewModels: [BannerViewModel]?
    var loopedViewModels: [BannerViewModel]?

    private var staticState: StaticState?
    private var scrollState: ScrollState?

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
            rootView.pageControl.isHidden = false
        } else {
            rootView.pageControl.isHidden = true
        }
    }

    func setupBannersCollection(with viewModels: [BannerViewModel]) {
        setViewModels(viewModels)

        rootView.collectionView.reloadData()

        staticState = .init(
            currentPage: 0,
            pageByActualOffset: 1
        )

        let itemIndex = viewModels.count > 1 ? 1 : 0

        scrollToItem(index: itemIndex)

        rootView.collectionView.alwaysBounceHorizontal = viewModels.count > 1
    }

    func scrollToItem(index: Int) {
        guard let staticState else { return }

        let indexPath = IndexPath(item: index, section: 0)

        scrollState = ScrollState(
            contentOffset: rootView.collectionView.contentOffset.x,
            pageWidth: rootView.collectionView.bounds.width,
            currentPage: staticState.currentPage
        )

        rootView.collectionView.scrollToItem(
            at: indexPath,
            at: .centeredHorizontally,
            animated: true
        )
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
        for newScrollState: ScrollState,
        _ oldScrollState: ScrollState
    ) -> CGFloat {
        guard let staticState, let viewModels else { return .zero }

        let scrollingForward: Bool = oldScrollState.contentOffset < newScrollState.contentOffset

        let roundedPageIndex = newScrollState.rawPageIndex.rounded(.down)
        let rawProgress = abs(
            (newScrollState.contentOffset - roundedPageIndex * newScrollState.pageWidth) / newScrollState.pageWidth
        )

        let draggedToNext = (
            scrollingForward &&
                newScrollState.rawPageIndex > CGFloat(staticState.pageByActualOffset)
        )
        let draggedToPrevious = (
            !scrollingForward &&
                newScrollState.rawPageIndex < CGFloat(staticState.pageByActualOffset)
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
        using scrollState: ScrollState,
        staticState: StaticState
    ) -> Int {
        let rawPageIndex = scrollState.rawPageIndex

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
            let scrollState,
            scrollState.rawPageIndex.rounded(.up) != scrollState.rawPageIndex.rounded(.down)
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
        for newScrollState: ScrollState,
        oldScrollState: ScrollState,
        targetPageIndex: Int
    ) {
        guard
            let staticState,
            let viewModels = loopedViewModels
        else { return }

        let progress = calculateTransitionProgress(
            for: newScrollState,
            oldScrollState
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
            let staticState,
            staticState.currentPage < viewModels.count
        else { return }

        let banner = viewModels[staticState.currentPage]

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

        setViewModels(updatedViewModel.banners)
        setupPageControl(for: updatedViewModel.banners)

        let nextItemIndex: Int

        if let loopedViewModels, staticState.pageByActualOffset < loopedViewModels.count - 1 {
            nextItemIndex = staticState.pageByActualOffset + 1
        } else {
            nextItemIndex = 0
        }

        rootView.collectionView.reloadData()

        scrollToItem(index: nextItemIndex)
        rootView.collectionView.alwaysBounceHorizontal = updatedViewModel.banners.count > 1
    }
}

// MARK: UIScrollViewDelegate

extension BannersViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let staticState, let scrollState else { return }

        let newScrollState = ScrollState(
            contentOffset: scrollView.contentOffset.x,
            pageWidth: scrollView.bounds.width,
            currentPage: staticState.currentPage
        )

        let targetPageIndex = calculateTargetPageIndex(
            using: newScrollState,
            staticState: staticState
        )
        let indicatorPageIndex = calculateIndicatorPageIndex(basedOn: targetPageIndex)

        rootView.pageControl.currentPage = indicatorPageIndex

        updateBackground(
            for: newScrollState,
            oldScrollState: scrollState,
            targetPageIndex: targetPageIndex
        )

        self.scrollState = newScrollState
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let staticState else { return }

        let scrollState = ScrollState(
            contentOffset: scrollView.contentOffset.x,
            pageWidth: scrollView.bounds.width,
            currentPage: staticState.currentPage
        )

        self.scrollState = scrollState
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
        scrollState = nil
    }
}
