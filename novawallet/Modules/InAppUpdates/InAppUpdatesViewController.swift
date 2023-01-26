import UIKit
import SoraFoundation

final class InAppUpdatesViewController: UIViewController, ViewHolder {
    typealias RootViewType = InAppUpdatesViewLayout

    let presenter: InAppUpdatesPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, VersionTableViewCell.Model>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, VersionTableViewCell.Model>
    private var dataSource: DataSource?
    private var isCriticalBanner: Bool = false

    init(
        presenter: InAppUpdatesPresenterProtocol,
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
        view = InAppUpdatesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let dataSource = createDataSource()
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
        self.dataSource = dataSource

        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, indexPath, model -> UITableViewCell? in
            guard let self = self else {
                return nil
            }

            let cell: VersionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(model: model, locale: self.selectedLocale)
            return cell
        }
    }

    private func setupLocalization() {}
}

extension InAppUpdatesViewController: InAppUpdatesViewProtocol {
    func didReceive(versionModels: [VersionTableViewCell.Model]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(versionModels)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }

    func didReceiveBannerState(isCritical: Bool) {
        isCriticalBanner = isCritical
        rootView.tableView.reloadData()
    }
}

extension InAppUpdatesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let selectedItem = dataSource?.itemIdentifier(for: indexPath) else {
            return
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let view: GradientBannerHeaderView = tableView.dequeueReusableHeaderFooterView()
        view.bind(isCritical: isCriticalBanner, locale: selectedLocale)
        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        132
    }
}

extension InAppUpdatesViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
