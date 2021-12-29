import UIKit
import SoraFoundation
import SubstrateSdk

final class DAppListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol

    init(presenter: DAppListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    private var accountIcon: UIImage?

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

        rootView.collectionViewLayout?.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        rootView.collectionView.dataSource = self
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

extension DAppListViewController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
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

    func numberOfSections(in _: UICollectionView) -> Int {
        1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        1
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

    func didReceive(state _: DAppListState) {}

    func didReceiveDApps(viewModels _: [DAppViewModel]) {}
}

extension DAppListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadSections([0])
        }
    }
}

extension DAppListViewController: HiddableBarWhenPushed {}
