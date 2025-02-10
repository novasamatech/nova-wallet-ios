import UIKit
import Foundation

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol

    private var viewModels: [BannerViewModel]?

    private var lastContentOffset: CGFloat = 0
    private var lastCurrentPage: Int = 0

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

        let backgroundImage = viewModels[state.targetPageIndex].backgroundImage

        rootView.backgroundView.changeBackground(to: backgroundImage) {
            progress
        }
        rootView.pageControl.currentPage = state.targetPageIndex
    }
}

// MARK: BannersViewProtocol

extension BannersViewController: BannersViewProtocol {
    func update(with viewModel: LoadableViewModelState<[BannerViewModel]>?) {
        switch viewModel {
        case let .cached(banners), let .loaded(banners):
            viewModels = banners
            rootView.collectionView.reloadData()
            rootView.setBackgroundImage(banners.first?.backgroundImage)
            rootView.setDisplayContent()
            rootView.pageControl.numberOfPages = banners.count
        case .loading, .none:
            viewModels = nil
            rootView.setLoading()
        }
    }
}

// MARK: UICollectionViewDataSource

extension BannersViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        viewModels?.count ?? 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let viewModels, viewModels.count > indexPath.item else {
            return UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCellWithType(
            BannerCollectionViewCell.self,
            for: indexPath
        )!

        cell.bind(with: viewModels[indexPath.item])

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
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        lastCurrentPage = Int(scrollView.contentOffset.x / scrollView.bounds.width)
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
