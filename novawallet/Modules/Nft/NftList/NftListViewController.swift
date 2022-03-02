import UIKit
import SoraFoundation
import RobinHood

final class NftListViewController: UIViewController, ViewHolder {
    typealias RootViewType = NftListViewLayout

    let presenter: NftListPresenterProtocol

    init(presenter: NftListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NftListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
        setupLocalization()

        setupNavigationBarStyle()

        presenter.setup()
    }

    private func setupNavigationBarStyle() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = navigationBar.bounds.height
        let blurHeight = statusBarHeight + navBarHeight
        rootView.navBarBlurViewHeightConstraint.update(offset: blurHeight)
    }

    private func configureCollectionView() {
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.registerCellClass(NftListItemCell.self)
    }

    private func setupLocalization() {
        title = R.string.localizable.walletListYourNftsTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension NftListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        let contentInsets = NftListViewLayout.contentInsets
        let horizontalSpacing = NftListViewLayout.horizontalSpacing
        let spacing: CGFloat = contentInsets.left + contentInsets.right + horizontalSpacing

        let itemWidth = (collectionView.frame.width - spacing) / 2.0

        return CGSize(width: itemWidth, height: NftListItemCell.height)
    }
}

extension NftListViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        presenter.numberOfItems()
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(NftListItemCell.self, for: indexPath)!

        let viewModel = presenter.nft(at: indexPath.item)
        cell.bind(viewModel: viewModel)

        return cell
    }
}

extension NftListViewController: NftListViewProtocol {
    func didReceive(changes: [ListDifference<NftListViewModel>]) {
        rootView.collectionView.performBatchUpdates {
            changes.forEach { change in
                switch change {
                case let .insert(index, _):
                    let indexPath = IndexPath(item: index, section: 0)
                    rootView.collectionView.insertItems(at: [indexPath])
                case let .update(index, _, _):
                    let indexPath = IndexPath(item: index, section: 0)
                    rootView.collectionView.reloadItems(at: [indexPath])
                case let .delete(index, _):
                    let indexPath = IndexPath(item: index, section: 0)
                    rootView.collectionView.deleteItems(at: [indexPath])
                }
            }
        }
    }
}

extension NftListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
