import UIKit
import Foundation_iOS

final class DAppBrowserTabListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserTabListViewLayout

    typealias DataSource = UICollectionViewDiffableDataSource<Int, DAppBrowserTabViewModel>

    let presenter: DAppBrowserTabListPresenterProtocol
    let webViewPoolEraser: WebViewPoolEraserProtocol

    var viewModels: [DAppBrowserTabViewModel] = []

    private var scrollsToBottomOnLoad: Bool = false

    private lazy var dataSource = createDataSource()

    init(
        presenter: DAppBrowserTabListPresenterProtocol,
        webViewPoolEraser: WebViewPoolEraserProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.webViewPoolEraser = webViewPoolEraser
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
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

        setup()
    }
}

// MARK: Private

private extension DAppBrowserTabListViewController {
    func setup() {
        presenter.setup()

        setupCollection()
        setupActions()
        setupLocalization()
    }

    func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { [weak self] collectionView, indexPath, model -> UICollectionViewCell? in
                guard let self else { return nil }

                let cell = collectionView.dequeueReusableCellWithType(
                    DAppBrowserTabCollectionCell.self,
                    for: indexPath
                )!

                cell.view.bind(
                    viewModel: model,
                    delegate: self
                )

                return cell
            }
        )

        return dataSource
    }

    func setupCollection() {
        rootView.collectionView.registerCellClass(DAppBrowserTabCollectionCell.self)
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.doneButtonItem.title = R.string.localizable.commonDone(
            preferredLanguages: languages
        )
        rootView.closeAllButtonItem.title = R.string.localizable.commonCloseAll(
            preferredLanguages: languages
        )
    }

    func setupActions() {
        rootView.closeAllButtonItem.target = self
        rootView.closeAllButtonItem.action = #selector(actionCloseAll)

        rootView.newTabButtonItem.target = self
        rootView.newTabButtonItem.action = #selector(actionNewTab)

        rootView.doneButtonItem.target = self
        rootView.doneButtonItem.action = #selector(actionDone)
    }

    func scrollToLast() {
        let indexForLastItem = rootView.collectionView.numberOfItems(inSection: 0) - 1
        let indexPath = IndexPath(
            item: indexForLastItem,
            section: 0
        )

        rootView.collectionView.scrollToItem(
            at: indexPath,
            at: .bottom,
            animated: true
        )
    }

    func reloadCollection() {
        let snapshot = createSnapshot()
        dataSource.apply(snapshot)

        if scrollsToBottomOnLoad {
            scrollToLast()
            scrollsToBottomOnLoad.toggle()
        }
    }

    func createSnapshot() -> NSDiffableDataSourceSnapshot<Int, DAppBrowserTabViewModel> {
        var snapshot = NSDiffableDataSourceSnapshot<Int, DAppBrowserTabViewModel>()
        snapshot.appendSections([0])
        snapshot.appendItems(viewModels, toSection: 0)

        return snapshot
    }

    @objc func actionCloseAll() {
        webViewPoolEraser.removeAll()
        presenter.closeAllTabs()
    }

    @objc func actionNewTab() {
        presenter.openNewTab()
    }

    @objc func actionDone() {
        presenter.close()
    }
}

// MARK: DAppBrowserTabListViewProtocol

extension DAppBrowserTabListViewController: DAppBrowserTabListViewProtocol {
    func didReceive(_ viewModels: [DAppBrowserTabViewModel]) {
        self.viewModels = viewModels

        reloadCollection()
    }

    func setScrollsToLatestOnLoad() {
        scrollsToBottomOnLoad = true
    }
}

// MARK: DAppBrowserTabViewDelegate

extension DAppBrowserTabListViewController: DAppBrowserTabViewDelegate {
    func actionCloseTab(with id: UUID) {
        webViewPoolEraser.removeWebView(for: id)
        presenter.closeTab(with: id)
    }
}

// MARK: UICollectionViewDelegate

extension DAppBrowserTabListViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
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

// MARK: DAppBrowserTabViewTransitionProtocol

extension DAppBrowserTabListViewController: DAppBrowserTabViewTransitionProtocol {
    func getTabViewForTransition(for tabId: UUID) -> UIView? {
        guard
            let viewModel = viewModels.first(
                where: { $0.uuid == tabId }
            ),
            let indexPath = dataSource.indexPath(for: viewModel)
        else {
            return nil
        }

        rootView.collectionView.scrollToItem(
            at: indexPath,
            at: .centeredVertically,
            animated: true
        )

        guard let cell = rootView.collectionView.cellForItem(
            at: indexPath
        ) as? DAppBrowserTabCollectionCell else {
            return nil
        }

        return cell.view.imageView
    }
}

// MARK: Localizable

extension DAppBrowserTabListViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}

// MARK: Constants

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
