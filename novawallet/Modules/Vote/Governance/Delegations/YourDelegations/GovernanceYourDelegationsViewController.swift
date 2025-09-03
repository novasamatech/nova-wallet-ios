import UIKit
import Foundation_iOS

final class GovernanceYourDelegationsViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceYourDelegationsViewLayout

    let presenter: GovernanceYourDelegationsPresenterProtocol

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, AccountAddress>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, AccountAddress>

    private lazy var dataSource = createDataSource()
    private var dataStore: [AccountAddress: GovernanceYourDelegationCell.Model] = [:]

    init(presenter: GovernanceYourDelegationsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceYourDelegationsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if dataStore.isEmpty {
            rootView.updateLoadingState()
        }
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.governanceReferendumsYourDelegations()

        rootView.addDelegationButton.imageWithTitleView?.title = R.string.localizable
            .delegationsAddTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
    }

    private func setupHandlers() {
        rootView.tableView.delegate = self

        rootView.addDelegationButton.addTarget(
            self,
            action: #selector(actionAddDelegation),
            for: .touchUpInside
        )
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, indexPath, identifier -> UITableViewCell? in
            guard let self = self, let model = self.dataStore[identifier] else {
                return nil
            }

            let cell: GovernanceYourDelegationCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(viewModel: model, locale: self.selectedLocale)
            return cell
        }
    }

    @objc private func actionAddDelegation() {
        presenter.addDelegation()
    }
}

extension GovernanceYourDelegationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let address = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        presenter.selectDelegate(for: address)
    }
}

extension GovernanceYourDelegationsViewController: GovernanceYourDelegationsViewProtocol {
    func didReceive(viewModels: [GovernanceYourDelegationCell.Model]) {
        dataStore = viewModels.reduce(into: [AccountAddress: GovernanceYourDelegationCell.Model]()) { accum, model in
            accum[model.identifier] = model
        }

        let newIdentifiers = viewModels.map(\.identifier)

        let existingIdentifiers = Set(dataSource.snapshot().itemIdentifiers)
        let changedIdentifiers = existingIdentifiers.intersection(Set(newIdentifiers))

        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(newIdentifiers)

        if !changedIdentifiers.isEmpty {
            snapshot.reloadItems(Array(changedIdentifiers))
        }

        dataSource.apply(snapshot, animatingDifferences: false)

        if viewModels.isEmpty {
            rootView.startLoadingIfNeeded()
        } else {
            rootView.stopLoadingIfNeeded()
        }
    }
}

extension GovernanceYourDelegationsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
