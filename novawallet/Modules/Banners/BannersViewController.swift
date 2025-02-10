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

    private func setupCollectionView() {
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.registerCellClass(BannerCollectionViewCell.self)
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
    func updateBackground(for scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        let currentOffset = scrollView.contentOffset.x

        let isScrollingForward = currentOffset > lastContentOffset
        lastContentOffset = currentOffset

        let pageIndex = Int(currentOffset / pageWidth)

        let roundedPageIndex = if isScrollingForward {
            Int(floor(currentOffset / pageWidth))
        } else {
            Int(ceil(currentOffset / pageWidth))
        }

        let targetPageIndex = if isScrollingForward {
            Int(ceil(currentOffset / pageWidth))
        } else {
            Int(floor(currentOffset / pageWidth))
        }

        let isMovingToNextPage = targetPageIndex > lastCurrentPage
        lastCurrentPage = roundedPageIndex

        let rawProgress = (currentOffset - CGFloat(pageIndex) * pageWidth) / pageWidth

        let progress = if isMovingToNextPage {
            rawProgress
        } else {
            1 - rawProgress
        }

        guard
            let viewModels = viewModels,
            !viewModels.isEmpty,
            targetPageIndex < viewModels.count
        else { return }

        let backgroundImage = viewModels[targetPageIndex].backgroundImage

        rootView.backgroundView.changeBackground(to: backgroundImage) {
            progress
        }

        rootView.pageControl.currentPage = targetPageIndex

        print("Scrolling progress: \(progress)")
        print("Target image index: \(targetPageIndex)")
        print("Current page: \(pageIndex)")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateBackground(for: scrollView)
    }
}
