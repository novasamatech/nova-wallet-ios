import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol

    private var viewModels: [BannerViewModel]?
    private var loopedViewModels: [BannerViewModel]?

    private var bannerToClose: String?

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
        setupBannersCollection(with: widgetModel.banners)

        rootView.setBackgroundImage(widgetModel.banners.first?.backgroundImage)
        rootView.setCloseButton(available: widgetModel.showsCloseButton)
        rootView.pageControl.numberOfPages = widgetModel.banners.count
        rootView.pageControl.currentPage = 0
    }

    func setupBannersCollection(with viewModels: [BannerViewModel]) {
        setViewModels(viewModels)

        rootView.collectionView.reloadData()

        staticState = .init(
            currentPage: 0,
            pageByActualOffset: 1
        )

        let indexPath = if loopedViewModels != nil {
            IndexPath(item: 1, section: 0)
        } else {
            IndexPath(item: 0, section: 0)
        }

        rootView.collectionView.scrollToItem(
            at: indexPath,
            at: .centeredHorizontally,
            animated: false
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

        viewModels = updatedViewModel.banners

        let nextItemIndex = if staticState.currentPage < updatedViewModel.banners.count {
            staticState.currentPage
        } else {
            0
        }

        rootView.pageControl.numberOfPages = updatedViewModel.banners.count
        rootView.pageControl.currentPage = nextItemIndex

        let nextIndexPath = IndexPath(
            item: nextItemIndex,
            section: 0
        )

        rootView.collectionView.reloadData()
        rootView.collectionView.scrollToItem(
            at: nextIndexPath,
            at: .centeredHorizontally,
            animated: true
        )
    }
}

// MARK: UICollectionViewDataSource

extension BannersViewController: UICollectionViewDataSource {
    func collectionView(
        _: UICollectionView,
        numberOfItemsInSection _: Int
    ) -> Int {
        if let loopedViewModels {
            loopedViewModels.count
        } else if let viewModels {
            viewModels.count
        } else {
            0
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let viewModels else {
            return UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCellWithType(
            BannerCollectionViewCell.self,
            for: indexPath
        )!

        let actualViewModels = if let loopedViewModels {
            loopedViewModels
        } else {
            viewModels
        }

        cell.bind(with: actualViewModels[indexPath.item])

        return cell
    }
}

// MARK: UICollectionViewDelegate

extension BannersViewController: UICollectionViewDelegate {
    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard let viewModels else { return }

        let index = indexPath.item

        let bannerId = if let loopedViewModels {
            loopedViewModels[index].id
        } else {
            viewModels[index].id
        }

        presenter.action(for: bannerId)
    }
}

// MARK: UICollectionViewDelegateFlowLayout

extension BannersViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt _: IndexPath
    ) -> CGSize {
        rootView.backgroundView.bounds.size
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt _: Int
    ) -> CGFloat {
        .zero
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
