import UIKit

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    let presenter: BannersPresenterProtocol

    private var viewModels: LoadableViewModelState<[BannerViewModel]>?

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
        viewModels = viewModel
        rootView.collectionView.reloadData()

        if case let .loaded(banners) = viewModel {
            rootView.setBackgroundImage(banners.first?.backgroundImage)
        }
    }
}

// MARK: UICollectionViewDataSource

extension BannersViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        guard let viewModels else { return 0 }

        return switch viewModels {
        case .loading: 1
        case let .loaded(value), let .cached(value): value.count
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(
            BannerCollectionViewCell.self,
            for: indexPath
        )!

        if case let .loaded(viewModels) = viewModels {
            cell.view.configure(with: viewModels[indexPath.item])
        }

        return cell
    }
}

// MARK: UICollectionViewDelegate

extension BannersViewController: UICollectionViewDelegate {}
