import UIKit
import SoraFoundation

final class DAppBrowserTabListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserTabListViewLayout

    let presenter: DAppBrowserTabListPresenterProtocol

    var viewModels: [DAppBrowserTab] = []

    init(
        presenter: DAppBrowserTabListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
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

private extension DAppBrowserTabListViewController {
    func setup() {
        presenter.setup()

        setupCollection()
        setupActions()
        setupLocalization()
    }

    func setupCollection() {
        rootView.collectionView.registerCellClass(DAppBrowserTabCollectionCell.self)
        rootView.collectionView.dataSource = self
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

    @objc func actionCloseAll() {
        presenter.closeAllTabs()
    }

    @objc func actionNewTab() {
        presenter.openNewTab()
    }

    @objc func actionDone() {
        presenter.close()
    }
}

extension DAppBrowserTabListViewController: DAppBrowserTabListViewProtocol {
    func didReceive(_ viewModels: [DAppBrowserTab]) {
        self.viewModels = viewModels
        rootView.collectionView.reloadSections([0])
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

// MARK: Localizable

extension DAppBrowserTabListViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
