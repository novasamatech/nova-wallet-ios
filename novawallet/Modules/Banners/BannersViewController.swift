import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol

    private var viewModels: [BannerViewModel]?

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
    func setupActions() {
        rootView.closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    func setup(with widgetModel: BannersWidgetviewModel) {
        viewModels = widgetModel.banners
        rootView.collectionView.reloadData()
        staticState = .init(currentPage: 0)

        rootView.collectionView.scrollToItem(
            at: IndexPath(item: 0, section: 0),
            at: .centeredHorizontally,
            animated: true
        )

        rootView.setBackgroundImage(widgetModel.banners.first?.backgroundImage)
        rootView.setCloseButton(available: widgetModel.showsCloseButton)
        rootView.setDisplayContent()
        rootView.pageControl.numberOfPages = widgetModel.banners.count
        rootView.pageControl.currentPage = 0
    }

    func setupCollectionView() {
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.registerCellClass(BannerCollectionViewCell.self)
    }

    func calculateTransitionProgress(
        for newScrollState: ScrollState,
        _ oldScrollState: ScrollState?
    ) -> CGFloat {
        guard let staticState, let viewModels else { return .zero }

        let scrollingForward: Bool = if let oldOffset = oldScrollState?.virtualOffset {
            oldOffset < newScrollState.virtualOffset
        } else {
            newScrollState.virtualOffset > CGFloat(staticState.currentPage) * newScrollState.pageWidth
        }

        print("scrollingForward: \(scrollingForward)")

        let rawPageIndex = abs(newScrollState.rawPageIndex.rounded(.down))
        let rawProgress = abs((newScrollState.virtualOffset - rawPageIndex * newScrollState.pageWidth) / newScrollState.pageWidth)

        print("rawPageIndex: \(rawPageIndex)")
        print("rawProgress: \(rawProgress)")

        let draggedToNext = (
            scrollingForward &&
                rawPageIndex > CGFloat(staticState.currentPage)
        )
        let draggedToPrevious = (
            !scrollingForward &&
                rawPageIndex < CGFloat(staticState.currentPage)
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

    func updateBackground(
        for newScrollState: ScrollState,
        oldScrollState: ScrollState?
    ) {
        guard let staticState else { return }

        let progress = calculateTransitionProgress(for: newScrollState, oldScrollState)

        print("TRANSITION PROGRESS: \(progress)")

        guard
            let viewModels = viewModels,
            !viewModels.isEmpty
        else { return }

        let rawPageIndex = newScrollState.actualOffset / newScrollState.pageWidth

        let rawTargetPageIndex: Int = if CGFloat(staticState.currentPage) == rawPageIndex {
            staticState.currentPage
        } else if rawPageIndex - CGFloat(staticState.currentPage) > 1 {
            Int(floor(rawPageIndex))
        } else {
            staticState.currentPage + (rawPageIndex > CGFloat(staticState.currentPage) ? 1 : -1)
        }

        let targetPageIndex = rawTargetPageIndex % viewModels.count

        let backgroundImage = viewModels[targetPageIndex].backgroundImage

        rootView.backgroundView.changeBackground(to: backgroundImage) {
            progress
        }
        rootView.pageControl.currentPage = targetPageIndex

        print("TARGET PAGE INDEX: \(targetPageIndex)")
    }

    func calculateOffset(
        for scrollView: UIScrollView,
        scrollState: ScrollState
    ) -> (actualOffset: CGFloat, virtualOffset: CGFloat) {
        guard let viewModels else {
            return (scrollState.actualOffset, scrollState.virtualOffset)
        }

        let itemWidth = scrollView.bounds.width
        let fullContentSize = itemWidth * CGFloat(viewModels.count)

        var reuseDelta: CGFloat = 0
        var actualOffset: CGFloat = scrollView.contentOffset.x

        if scrollView.contentOffset.x > fullContentSize {
            reuseDelta = scrollView.contentOffset.x - fullContentSize
            actualOffset = reuseDelta
        }

        if scrollView.contentOffset.x < 0 {
            reuseDelta = scrollView.contentOffset.x
            actualOffset = reuseDelta + fullContentSize
        }

        let actualOffsetDelta = actualOffset - scrollState.actualOffset

        let virtualOffset = if reuseDelta != 0 {
            scrollState.virtualOffset + reuseDelta
        } else {
            scrollState.virtualOffset + actualOffsetDelta
        }

        return (actualOffset, virtualOffset)
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
        guard let viewModels else {
            return 0
        }

        return viewModels.count + 1
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

        let currentModelIndex = indexPath.item % viewModels.count
        cell.bind(with: viewModels[currentModelIndex])

        return cell
    }
}

// MARK: UICollectionViewDelegate

extension BannersViewController: UICollectionViewDelegate {
    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard let bannerId = viewModels?[indexPath.item].id else { return }

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

        let (actualOffset, virtualOffset) = calculateOffset(
            for: scrollView,
            scrollState: scrollState
        )

        let crossedBounds = virtualOffset != actualOffset
        scrollView.contentOffset.x = actualOffset

        let newScrollState = ScrollState(
            actualOffset: actualOffset,
            virtualOffset: virtualOffset,
            crossedBounds: crossedBounds,
            pageWidth: scrollView.bounds.width,
            currentPage: staticState.currentPage
        )

        print("Actual offset: \(actualOffset), virtual offset: \(virtualOffset), crossed bounds: \(newScrollState.crossedBounds)")

        updateBackground(
            for: newScrollState,
            oldScrollState: scrollState
        )
        self.scrollState = newScrollState
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let staticState else { return }

        let scrollState = ScrollState(
            actualOffset: scrollView.contentOffset.x,
            virtualOffset: scrollView.contentOffset.x,
            crossedBounds: false,
            pageWidth: scrollView.bounds.width,
            currentPage: staticState.currentPage
        )

        self.scrollState = scrollState
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let viewModels else { return }

        let lastCurrentPage = Int(
            round(
                Double(scrollView.contentOffset.x) / Double(scrollView.bounds.width)
            )
        ) % viewModels.count

        staticState = StaticState(currentPage: lastCurrentPage)
        scrollState = nil
    }
}

// MARK: ScrollState

private extension BannersViewController {
    struct StaticState {
        let currentPage: Int
    }

    struct ScrollState {
        private let currentPage: Int

        let crossedBounds: Bool
        let actualOffset: CGFloat
        let virtualOffset: CGFloat
        let pageWidth: CGFloat

        var rawPageIndex: CGFloat {
            virtualOffset / pageWidth
        }

        init(
            actualOffset: CGFloat,
            virtualOffset: CGFloat,
            crossedBounds: Bool,
            pageWidth: CGFloat,
            currentPage: Int
        ) {
            self.virtualOffset = virtualOffset
            self.actualOffset = actualOffset
            self.crossedBounds = crossedBounds
            self.pageWidth = pageWidth
            self.currentPage = currentPage
        }
    }
}
