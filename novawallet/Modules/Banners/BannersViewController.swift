import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol
    let dataSource: BannersViewDataSourceProtocol

    private var staticState: StaticState?
    private var dynamicState: DynamicState?

    init(presenter: BannersPresenterProtocol) {
        self.presenter = presenter
        dataSource = BannersViewDataSource()
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
        dataSource.update(with: viewModels)

        let multipleBanners: Bool = viewModels.count > 1
        let itemIndex = multipleBanners ? 1 : 0

        staticState = .init(
            currentPage: 0,
            pageByActualOffset: itemIndex
        )

        rootView.collectionView.reloadData { [weak self] in
            self?.scrollToItem(
                index: itemIndex,
                animated: false
            ) {
                self?.rootView.collectionView.alwaysBounceHorizontal = multipleBanners
            }
        }
    }

    func scrollToItem(
        index: Int,
        animated: Bool,
        completionBlock: (() -> Void)? = nil
    ) {
        guard let staticState else { return }

        let indexPath = IndexPath(item: index, section: 0)

        if animated {
            dynamicState = DynamicState(
                contentOffset: rootView.collectionView.contentOffset.x,
                pageWidth: rootView.collectionView.bounds.width
            )
        }

        CATransaction.setCompletionBlock {
            completionBlock?()
        }
        CATransaction.begin()

        rootView.collectionView.scrollTo(
            horizontalPage: index,
            animated: animated
        )

        CATransaction.commit()
    }

    func calculateTransitionProgress(
        for newDynamicState: DynamicState,
        _ oldDynamicState: DynamicState
    ) -> CGFloat {
        guard let staticState else { return .zero }

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

        let targetPageIndex: Int

        if CGFloat(staticState.pageByActualOffset) == rawPageIndex {
            targetPageIndex = staticState.pageByActualOffset
        } else {
            let newIndex = staticState.pageByActualOffset + (rawPageIndex > CGFloat(staticState.pageByActualOffset) ? 1 : -1)
            targetPageIndex = abs(Int(rawPageIndex) - staticState.pageByActualOffset) > 1 ? Int(rawPageIndex) : newIndex
        }

        return targetPageIndex
    }

    func updateBackground(
        for newDynamicState: DynamicState,
        oldDynamicState: DynamicState,
        targetPageIndex: Int
    ) {
        guard let banner = dataSource.getItem(at: targetPageIndex) else { return }

        let progress = calculateTransitionProgress(
            for: newDynamicState,
            oldDynamicState
        )

        rootView.backgroundView.changeBackground(
            to: banner.backgroundImage,
            progress: progress
        )
    }

    func changeCurrentOffsetIfNeeded(
        for scrollView: UIScrollView,
        currentPageByOffset: Int
    ) {
        let itemWidth = scrollView.bounds.width
        let fullContentWidth = itemWidth * CGFloat(dataSource.itemsCount())

        let trailingLoopingPage: Int = dataSource.itemsCount() - 1
        let leadingLoopingPage: Int = 0

        if currentPageByOffset == leadingLoopingPage {
            scrollView.contentOffset.x = itemWidth * CGFloat(trailingLoopingPage - 1)
        } else if currentPageByOffset == trailingLoopingPage {
            scrollView.contentOffset.x = itemWidth
        }
    }

    // MARK: Actions

    @objc func actionClose() {
        guard
            let staticState,
            let banner = dataSource.getItem(at: staticState.pageByActualOffset)
        else { return }

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
            dataSource.update(with: nil)
            rootView.setLoading()
        }
    }

    func didCloseBanner(updatedViewModel: BannersWidgetviewModel) {
        guard
            let staticState,
            !updatedViewModel.banners.isEmpty,
            let nextItemIndex = dataSource.nextShowingItemIndex(after: staticState.pageByActualOffset)
        else { return }

        scrollToItem(
            index: nextItemIndex,
            animated: true
        ) { [weak self] in
            guard let self else { return }

            dataSource.update(with: updatedViewModel.banners)
            setupPageControl(for: updatedViewModel.banners)

            let pageByActualOffset = nextItemIndex - 1
            self.staticState = .init(
                currentPage: staticState.currentPage,
                pageByActualOffset: pageByActualOffset
            )

            let pageWidth = rootView.collectionView.bounds.width

            rootView.collectionView.reloadData()
            rootView.collectionView.contentOffset.x = CGFloat(pageByActualOffset) * pageWidth
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
            pageWidth: scrollView.bounds.width
        )

        let targetIetmIndex = calculateTargetPageIndex(
            using: newDynamicState,
            staticState: staticState
        )
        let indicatorPageIndex = dataSource.pageIndex(for: targetIetmIndex)

        rootView.pageControl.currentPage = indicatorPageIndex

        updateBackground(
            for: newDynamicState,
            oldDynamicState: dynamicState,
            targetPageIndex: targetIetmIndex
        )

        self.dynamicState = newDynamicState
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let staticState else { return }

        let dynamicState = DynamicState(
            contentOffset: scrollView.contentOffset.x,
            pageWidth: scrollView.bounds.width
        )

        self.dynamicState = dynamicState
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollViewDidEndDecelerating(scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageByOffsetBeforeChanges = Int(
            round(scrollView.contentOffset.x / scrollView.bounds.width)
        )

        let currentPage = pageByOffsetBeforeChanges % dataSource.itemsCount()

        changeCurrentOffsetIfNeeded(
            for: scrollView,
            currentPageByOffset: pageByOffsetBeforeChanges
        )

        let pageByOffsetAfterChanges = Int(
            round(scrollView.contentOffset.x / scrollView.bounds.width)
        )

        staticState = StaticState(
            currentPage: currentPage,
            pageByActualOffset: pageByOffsetAfterChanges
        )

        dynamicState = nil
    }
}
