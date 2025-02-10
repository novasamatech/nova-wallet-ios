import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol

    private var viewModels: [BannerViewModel]?

    private var lastContentOffset: CGFloat = 0
    private var lastCurrentPage: Int = 0
    private var bannerToClose: String?

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
        lastContentOffset = 0
        lastCurrentPage = 0
    }

    func setupCollectionView() {
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.registerCellClass(BannerCollectionViewCell.self)
    }

    func calculateTransitionProgress(state: ScrollState) -> CGFloat {
        let roundedDownPage = state.rawPageIndex.rounded(.down)
        let rawProgress = abs((state.currentOffset - roundedDownPage * state.pageWidth) / state.pageWidth)

        let changesPage: Bool = (state.scrollingForward && (state.rawPageIndex > CGFloat(lastCurrentPage)))
            || (!state.scrollingForward && state.rawPageIndex < CGFloat(lastCurrentPage))

        return if changesPage {
            state.scrollingForward
                ? (rawProgress == 0 ? 1.0 : rawProgress)
                : (1 - rawProgress)
        } else {
            state.scrollingForward
                ? (rawProgress == 0 ? rawProgress : 1 - rawProgress)
                : rawProgress
        }
    }

    func updateBackground(for scrollView: UIScrollView) {
        let state = ScrollState(
            scrollView: scrollView,
            lastOffset: lastContentOffset,
            lastPage: lastCurrentPage
        )
        lastContentOffset = state.currentOffset

        let progress = calculateTransitionProgress(state: state)

        guard
            let viewModels = viewModels,
            !viewModels.isEmpty,
            state.targetPageIndex < viewModels.count
        else { return }

        let targetPageindex = state.targetPageIndex % viewModels.count

        let backgroundImage = viewModels[targetPageindex].backgroundImage

        rootView.backgroundView.changeBackground(to: backgroundImage) {
            progress
        }
        rootView.pageControl.currentPage = targetPageindex
    }

    // MARK: Actions

    @objc func actionClose() {
        guard
            let viewModels,
            lastCurrentPage < viewModels.count
        else { return }

        let banner = viewModels[lastCurrentPage]

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
        viewModels = updatedViewModel.banners

        let nextItemIndex = if lastCurrentPage < updatedViewModel.banners.count {
            lastCurrentPage
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
        updateBackground(for: scrollView)
        setOffsets(for: scrollView)
    }

    func setOffsets(for scrollView: UIScrollView) {
        guard let viewModels else { return }

        let itemWidth = scrollView.bounds.width
        if scrollView.contentOffset.x > itemWidth * CGFloat(viewModels.count) {
            rootView.collectionView.contentOffset.x -= itemWidth * CGFloat(viewModels.count)
        }
        if scrollView.contentOffset.x <= 0 {
            rootView.collectionView.contentOffset.x += itemWidth * CGFloat(viewModels.count)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let viewModels else { return }

        lastCurrentPage = Int(
            round(
                Double(scrollView.contentOffset.x) / Double(scrollView.bounds.width)
            )
        ) % viewModels.count
    }
}

// MARK: ScrollState

private extension BannersViewController {
    struct ScrollState {
        private let lastPage: Int
        private let lastOffset: CGFloat

        let currentOffset: CGFloat
        let pageWidth: CGFloat

        var rawPageIndex: CGFloat {
            currentOffset / pageWidth
        }

        var scrollingForward: Bool {
            currentOffset > lastOffset
        }

        var targetPageIndex: Int {
            if CGFloat(lastPage) == rawPageIndex {
                lastPage
            } else {
                max(lastPage + (rawPageIndex > CGFloat(lastPage) ? 1 : -1), 0)
            }
        }

        init(
            scrollView: UIScrollView,
            lastOffset: CGFloat,
            lastPage: Int
        ) {
            currentOffset = scrollView.contentOffset.x
            pageWidth = scrollView.bounds.width

            self.lastOffset = lastOffset
            self.lastPage = lastPage
        }
    }
}
