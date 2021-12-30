import UIKit
import SoraFoundation
import SubstrateSdk

final class DAppListViewController: UIViewController, ViewHolder {
    enum Section: Int {
        case header
        case items
    }

    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol

    init(presenter: DAppListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    private var accountIcon: UIImage?

    private var state: DAppListState?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()

        presenter.setup()
    }

    private func configureCollectionView() {
        rootView.collectionView.registerCellClass(DAppListHeaderView.self)
        rootView.collectionView.registerCellClass(DAppCategoriesView.self)
        rootView.collectionView.registerCellClass(DAppItemView.self)

        rootView.collectionViewLayout?.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
    }

    private func updateIcon(for headerView: DAppListHeaderView, icon _: UIImage?) {
        headerView.accountButton.imageWithTitleView?.iconImage = accountIcon
        headerView.accountButton.invalidateLayout()
    }

    @objc func actionSelectAccount() {
        presenter.activateAccount()
    }

    @objc func actionSearch() {
        presenter.activateSearch()
    }
}

extension DAppListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard case .loaded = state, let section = Section(rawValue: indexPath.section) else {
            return
        }

        switch section {
        case .items:
            if indexPath.row > 0 {
                presenter.selectDApp(at: indexPath.row - 1)
            }
        case .header:
            break
        }
    }
}

extension DAppListViewController: UICollectionViewDataSource {
    private func setupHeaderView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppListHeaderView = collectionView.dequeueReusableCellWithType(
            DAppListHeaderView.self,
            for: indexPath
        )!

        updateIcon(for: view, icon: accountIcon)

        view.accountButton.addTarget(self, action: #selector(actionSelectAccount), for: .touchUpInside)
        view.searchView.addTarget(self, action: #selector(actionSearch), for: .touchUpInside)

        view.selectedLocale = selectedLocale

        return view
    }

    private func setupCategoriesView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppCategoriesView = collectionView.dequeueReusableCellWithType(
            DAppCategoriesView.self,
            for: indexPath
        )!

        view.delegate = self

        let numberOfCategories = presenter.numberOfCategories()
        let allCategories = (0 ..< numberOfCategories).map { presenter.category(at: $0) }

        view.bind(categories: allCategories)

        return view
    }

    private func setupDAppView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppItemView = collectionView.dequeueReusableCellWithType(DAppItemView.self, for: indexPath)!

        let dApp = presenter.dApp(at: indexPath.row - 1)
        view.bind(viewModel: dApp)

        return view
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UICollectionViewCell()
        }

        switch section {
        case .header:
            return setupHeaderView(using: collectionView, indexPath: indexPath)
        case .items:
            if indexPath.row == 0 {
                return setupCategoriesView(using: collectionView, indexPath: indexPath)
            } else {
                return setupDAppView(using: collectionView, indexPath: indexPath)
            }
        }
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        state != nil ? 2 : 1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            switch state {
            case .error, .loading:
                return 0
            case .loaded:
                return presenter.numberOfDApps() + 1
            case .none:
                return 0
            }
        }
    }
}

extension DAppListViewController: DAppCategoriesViewDelegate {
    func dAppCategories(view _: DAppCategoriesView, didSelectItemAt index: Int) {
        presenter.selectCategory(at: index)
    }
}

extension DAppListViewController: DAppListViewProtocol {
    func didReceiveAccount(icon: DrawableIcon) {
        let iconSize = CGSize(
            width: UIConstants.navigationAccountIconSize,
            height: UIConstants.navigationAccountIconSize
        )

        accountIcon = icon.imageWithFillColor(.clear, size: iconSize, contentScale: UIScreen.main.scale)

        if let headerView = rootView.findHeaderView() {
            updateIcon(for: headerView, icon: accountIcon)
        }
    }

    func didReceive(state: DAppListState) {
        self.state = state

        rootView.collectionView.reloadData()
    }
}

extension DAppListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}

extension DAppListViewController: HiddableBarWhenPushed {}
