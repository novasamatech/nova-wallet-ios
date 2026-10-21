import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol
    let dataSource: BannersViewDataSourceProtocol

    private lazy var autoScrollManager: AutoScrollManager = {
        AutoScrollManager(scrollable: self)
    }()

    private var staticState: StaticState?
    private var dynamicState: DynamicState?

    var pinnedBackgroundItemIndex: Int?

    var maxContentHeight = BannersViewLayout.Constants.contentMinHeight

    var maxWidgetHeight: CGFloat {
        maxContentHeight + BannersViewLayout.Constants.pageControlHeight
    }

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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        presenter.setup(with: rootView.availableTextWidth)
        updateBackground()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        rootView.restartLoadingIfNeeded()
        setupAutoScroll()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        autoScrollManager.stopScrolling()
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

    func updateMaxWidgetHeight(for widgetViewModel: BannersWidgetViewModel) {
        let oldHeight = maxContentHeight
        let height = widgetViewModel.maxTextHeight
            + BannerView.Constants.textContainerVerticalInset * 2
            + BannerView.Constants.contentImageViewVerticalInset * 2

        maxContentHeight = height

        if height != oldHeight {
            rootView.collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    func setup(with widgetModel: BannersWidgetViewModel) {
        setupBannersCollection(with: widgetModel.banners)
        setupPageControl()

        updateBackground()
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
        pinnedBackgroundItemIndex = itemIndex
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

    func updateCollectionOnClose(with updatedModel: BannersWidgetViewModel) {
        guard let staticState else { return }

        dataSource.update(with: updatedModel.banners)
        setupPageControl()

        let currentItemIndexAfterClose = (staticState.itemByActualOffset - 1)

        let itemByActualOffset: Int = if dataSource.multipleBanners {
            if
                let lastItemIndex = dataSource.lastIndex,
                let firstShowingItemIndex = dataSource.firstShowingItemIndex,
                currentItemIndexAfterClose >= lastItemIndex {
                firstShowingItemIndex
            } else {
                currentItemIndexAfterClose == 0 ? 1 : currentItemIndexAfterClose
            }
        } else {
            0
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
        guard staticState != nil else { return }

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

    func calculateTargetItemIndex(
        using dynamicState: DynamicState,
        staticState: StaticState
    ) -> Int {
        let rawItemIndex = dynamicState.rawItemIndex

        let targetItemIndex: Int

        if CGFloat(staticState.itemByActualOffset) == rawItemIndex {
            targetItemIndex = staticState.itemByActualOffset
        } else {
            let newIndex = staticState.itemByActualOffset
                + (rawItemIndex > CGFloat(staticState.itemByActualOffset) ? 1 : -1)
            targetItemIndex = abs(Int(rawItemIndex) - staticState.itemByActualOffset) > 1 ? Int(rawItemIndex) : newIndex
        }

        return targetItemIndex
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

    private func setupAutoScroll() {
        guard dataSource.multipleBanners else {
            autoScrollManager.stopScrolling()

            return
        }

        autoScrollManager.setupScrolling()
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
    func update(with viewModel: LoadableViewModelState<BannersWidgetViewModel>?) {
        autoScrollManager.stopScrolling()

        switch viewModel {
        case let .cached(model), let .loaded(model):
            setup(with: model)
            updateMaxWidgetHeight(for: model)
            setupAutoScroll()
            rootView.setLoaded()
        case .loading, .none:
            dataSource.update(with: nil)
            rootView.setLoading()
        }
    }

    func didCloseBanner(updatedViewModel: BannersWidgetViewModel) {
        autoScrollManager.stopScrolling()
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
            self?.setupAutoScroll()
        }
    }

    func getMaxBannerHeight() -> CGFloat {
        maxWidgetHeight
    }

    func getAvailableTextWidth() -> CGFloat {
        rootView.availableTextWidth
    }
}

// MARK: UIScrollViewDelegate

extension BannersViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateBackground()

        guard let staticState, dynamicState != nil else { return }

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

        dynamicState = newDynamicState
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard staticState != nil else { return }

        autoScrollManager.stopScrolling()
        unpinBackground()

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
        unpinBackground()
    }
}

// MARK: AutoScrollable

extension BannersViewController: AutoScrollable {
    func scrollToNextItem() {
        guard let staticState else { return }

        scrollToItem(
            index: staticState.itemByActualOffset + 1,
            animated: true
        )
    }
}
