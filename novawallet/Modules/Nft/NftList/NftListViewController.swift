import UIKit
import SoraFoundation
import RobinHood

final class NftListViewController: UIViewController, ViewHolder {
    private enum Constants {
        static let cellWithoutPriceHeight: CGFloat = 224.0
        static let cellWithPriceHeight: CGFloat = 262.0
    }

    typealias RootViewType = NftListViewLayout

    let presenter: NftListPresenterProtocol

    let quantityFormater: LocalizableResource<NumberFormatter>

    init(
        presenter: NftListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.presenter = presenter
        quantityFormater = quantityFormatter
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
        setupHandlers()

        setupNavigationBarStyle()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.collectionView.refreshControl?.addTarget(self, action: #selector(actionRefresh), for: .valueChanged)
    }

    private func setupNavigationBarStyle() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = navigationBar.bounds.height
        let blurHeight = statusBarHeight + navBarHeight
        rootView.navBarBlurViewHeightConstraint.update(offset: blurHeight)
    }

    private func updateCounter() {
        let numberOfItems = presenter.numberOfItems()

        if
            let counterString = quantityFormater.value(for: selectedLocale).string(
                from: NSNumber(value: numberOfItems)
            ) {
            rootView.counterView.titleLabel.text = counterString

            let barItem = UIBarButtonItem(customView: rootView.counterView)
            navigationItem.rightBarButtonItem = barItem
        } else {
            rootView.counterView.titleLabel.text = ""
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func configureCollectionView() {
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.registerCellClass(NftListItemWithPriceCell.self)
    }

    private func setupLocalization() {
        title = R.string.localizable.walletListYourNftsTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    private func preferredItemWidth(from totalWidth: CGFloat) -> CGFloat {
        let contentInsets = NftListViewLayout.contentInsets
        let horizontalSpacing = NftListViewLayout.horizontalSpacing
        let spacing: CGFloat = contentInsets.left + contentInsets.right + horizontalSpacing

        return (totalWidth - spacing) / 2.0
    }

    @objc func actionRefresh() {
        presenter.refresh()
    }
}

extension NftListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt _: IndexPath
    ) -> CGSize {
        let itemWidth = preferredItemWidth(from: collectionView.frame.width)

        return CGSize(width: itemWidth, height: Constants.cellWithPriceHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        presenter.selectNft(at: indexPath.item)
    }
}

extension NftListViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        presenter.numberOfItems()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let viewModel = presenter.nft(at: indexPath.item)

        let cell = collectionView.dequeueReusableCellWithType(NftListItemWithPriceCell.self, for: indexPath)!
        cell.locale = selectedLocale

        let itemWidth = preferredItemWidth(from: collectionView.frame.width)

        cell.bind(viewModel: viewModel, preferredWidth: itemWidth)

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

        updateCounter()
    }

    func didCompleteRefreshing() {
        rootView.collectionView.refreshControl?.endRefreshing()
    }
}

extension NftListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            updateCounter()
        }
    }
}
