import UIKit

final class DAppBrowserTabListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserTabListViewLayout

    let presenter: DAppBrowserTabListPresenterProtocol

    var viewModels: [DAppBrowserTab] = []

    init(presenter: DAppBrowserTabListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppBrowserTabListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupCollection()
    }
}

private extension DAppBrowserTabListViewController {
    func setupCollection() {
        rootView.collectionView.registerCellClass(DAppBrowserTabCollectionCell.self)
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
    }
}

extension DAppBrowserTabListViewController: DAppBrowserTabListViewProtocol {
    func didReceive(_ viewModels: [DAppBrowserTab]) {
        self.viewModels = viewModels
        rootView.collectionView.reloadData()
    }
}

// MARK: UICollectionViewDataSource

extension DAppBrowserTabListViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        viewModels.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let viewModel = viewModels[indexPath.item]

        let cell = collectionView.dequeueReusableCellWithType(DAppBrowserTabCollectionCell.self, for: indexPath)!
        cell.view.bind(viewModel: viewModel)

        return cell
    }
}

// MARK: UICollectionViewDelegate

extension DAppBrowserTabListViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let tab = viewModels[indexPath.item]

        presenter.selectTab(with: tab.uuid)
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt _: Int
    ) -> UIEdgeInsets {
        UIEdgeInsets(
            top: 0,
            left: Constants.itemEdgeInset,
            bottom: Constants.bottomInset,
            right: Constants.itemEdgeInset
        )
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt _: IndexPath
    ) -> CGSize {
        CGSize(
            width: Constants.itemWidth,
            height: Constants.itemHeight
        )
    }
}

private extension DAppBrowserTabListViewController {
    enum Constants {
        static let itemEdgeInset: CGFloat = 16
        static let interItemSpacing: CGFloat = 16
        static let bottomInset: CGFloat = 24

        static let itemWidth: CGFloat = (
            UIScreen.main.bounds.width
                - itemEdgeInset * 2
                - interItemSpacing
        ) / 2

        static let itemHeight: CGFloat = itemWidth * 1.55
    }
}
