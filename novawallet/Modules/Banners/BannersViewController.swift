import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol
    let dataSource: BannersViewDataSourceProtocol

    private var staticState: StaticState?
    private var dynamicState: DynamicState?

    private var maxWidgetHeight: CGFloat = 0

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

    func updateMaxWidgetHeight(for widgetViewModel: BannersWidgetviewModel) {
        let height = widgetViewModel.maxTextHeight
            + BannerView.Constants.textContainerTopInset
            + BannerView.Constants.textContainerBottomInset
            + BannerView.Constants.contentImageViewVerticalInset * 2

        maxWidgetHeight = height
    }

    func setup(with widgetModel: BannersWidgetviewModel) {
        setupBannersCollection(with: widgetModel.banners)
        setupPageControl()

        rootView.setBackgroundImage(widgetModel.banners.first?.backgroundImage)
        rootView.setCloseButton(available: widgetModel.showsCloseButton)
    }

    func setupPageControl() {
        guard let staticState else { return }

        rootView.pageControl.currentPage = dataSource.pageIndex(for: staticState.itemByActualOffset)

        if dataSource.multipleBanners {
            rootView.pageControl.numberOfPages = dataSource.numberOfPages()
            rootView.pageControl.show()
        } else {
            rootView.pageControl.hide()
        }
    }

    func setupBannersCollection(with viewModels: [BannerViewModel]) {
        dataSource.update(with: viewModels)

        let itemIndex = dataSource.firstShowingItemIndex ?? 0

        staticState = .init(itemByActualOffset: itemIndex)
        rootView.collectionView.reloadData { [weak self] in
            guard let self else { return }

            scrollToItem(
                index: itemIndex,
                animated: true
            ) {
                self.rootView.collectionView.alwaysBounceHorizontal = self.dataSource.multipleBanners
            }
        }
    }

    func updateCollectionOnClose(with updatedModel: BannersWidgetviewModel) {
        guard let staticState else { return }

        dataSource.update(with: updatedModel.banners)
        setupPageControl()

        let itemByActualOffset: Int = if
            let lastItemIndex = dataSource.lastIndex,
            let firstShowingItemIndex = dataSource.firstShowingItemIndex,
            staticState.itemByActualOffset >= lastItemIndex {
            firstShowingItemIndex
        } else {
            staticState.itemByActualOffset
        }

        self.staticState = .init(itemByActualOffset: itemByActualOffset)

        let itemWidth = rootView.collectionView.bounds.width

        rootView.collectionView.reloadData()
        rootView.collectionView.contentOffset.x = CGFloat(itemByActualOffset) * itemWidth
        rootView.collectionView.alwaysBounceHorizontal = dataSource.multipleBanners
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
                itemWidth: rootView.collectionView.bounds.width
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

        let roundedItemIndex = newDynamicState.rawItemIndex.rounded(.down)
        let rawProgress = abs(
            (newDynamicState.contentOffset - roundedItemIndex * newDynamicState.itemWidth) / newDynamicState.itemWidth
        )

        let draggedToNext = (
            scrollingForward &&
                newDynamicState.rawItemIndex > CGFloat(staticState.itemByActualOffset)
        )
        let draggedToPrevious = (
            !scrollingForward &&
                newDynamicState.rawItemIndex < CGFloat(staticState.itemByActualOffset)
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

    func calculateTargetItemIndex(
        using dynamicState: DynamicState,
        staticState: StaticState
    ) -> Int {
        let rawItemIndex = dynamicState.rawItemIndex

        let targetItemIndex: Int

        if CGFloat(staticState.itemByActualOffset) == rawItemIndex {
            targetItemIndex = staticState.itemByActualOffset
        } else {
            let newIndex = staticState.itemByActualOffset + (rawItemIndex > CGFloat(staticState.itemByActualOffset) ? 1 : -1)
            targetItemIndex = abs(Int(rawItemIndex) - staticState.itemByActualOffset) > 1 ? Int(rawItemIndex) : newIndex
        }

        return targetItemIndex
    }

    func updateBackground(
        for newDynamicState: DynamicState,
        oldDynamicState: DynamicState,
        targetItemIndex: Int
    ) {
        guard let banner = dataSource.getItem(at: targetItemIndex) else { return }

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
        currentItemByOffset: Int
    ) {
        guard
            let lastIndex = dataSource.lastIndex,
            let firstIndex = dataSource.firstIndex,
            let lastShowingItemIndex = dataSource.lastShowingItemIndex
        else { return }

        let itemWidth = scrollView.bounds.width
        let fullContentWidth = itemWidth * CGFloat(dataSource.numberOfItems())

        if currentItemByOffset == firstIndex {
            scrollView.contentOffset.x = itemWidth * CGFloat(lastShowingItemIndex)
        } else if currentItemByOffset == lastIndex {
            scrollView.contentOffset.x = itemWidth
        }

        let itemByOffsetChanges = Int(
            round(scrollView.contentOffset.x / scrollView.bounds.width)
        )

        staticState = StaticState(itemByActualOffset: itemByOffsetChanges)
    }

    // MARK: Actions

    @objc func actionClose() {
        guard
            let staticState,
            let banner = dataSource.getItem(at: staticState.itemByActualOffset)
        else { return }

        presenter.closeBanner(with: banner.id)
    }
}

// MARK: BannersViewProtocol

extension BannersViewController: BannersViewProtocol {
    func update(with viewModel: LoadableViewModelState<BannersWidgetviewModel>?) {
        switch viewModel {
        case let .cached(model), let .loaded(model):
            updateMaxWidgetHeight(for: model)
            setup(with: model)
            rootView.setLoaded()
        case .loading, .none:
            dataSource.update(with: nil)
            rootView.setLoading()
        }
    }

    func didCloseBanner(updatedViewModel: BannersWidgetviewModel) {
        updateMaxWidgetHeight(for: updatedViewModel)

        guard
            let staticState,
            !updatedViewModel.banners.isEmpty
        else { return }

        let nextItemIndex = staticState.itemByActualOffset + 1

        scrollToItem(
            index: nextItemIndex,
            animated: true
        ) { [weak self] in
            self?.updateCollectionOnClose(with: updatedViewModel)
        }
    }

    func getMaxBannerHeight() -> CGFloat {
        maxWidgetHeight
    }
}

// MARK: UIScrollViewDelegate

extension BannersViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let staticState, let dynamicState else { return }

        let newDynamicState = DynamicState(
            contentOffset: scrollView.contentOffset.x,
            itemWidth: scrollView.bounds.width
        )

        let targetItemIndex = calculateTargetItemIndex(
            using: newDynamicState,
            staticState: staticState
        )
        let pageIndex = dataSource.pageIndex(for: targetItemIndex)

        rootView.pageControl.currentPage = pageIndex

        updateBackground(
            for: newDynamicState,
            oldDynamicState: dynamicState,
            targetItemIndex: targetItemIndex
        )

        self.dynamicState = newDynamicState
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let staticState else { return }

        let dynamicState = DynamicState(
            contentOffset: scrollView.contentOffset.x,
            itemWidth: scrollView.bounds.width
        )

        self.dynamicState = dynamicState
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollViewDidEndDecelerating(scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let itemByOffsetBeforeChanges = Int(
            round(scrollView.contentOffset.x / scrollView.bounds.width)
        )

        changeCurrentOffsetIfNeeded(
            for: scrollView,
            currentItemByOffset: itemByOffsetBeforeChanges
        )

        dynamicState = nil
    }
}
