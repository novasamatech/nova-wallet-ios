import UIKit
import SoraFoundation

final class ReferendumVotersViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumVotersViewLayout
    typealias DataSource = UITableViewDiffableDataSource<String, ReferendumVotersViewModel>

    private var dataSource: DataSource?
    private let votersType: ReferendumVotersType
    private let quantityFormatter: LocalizableResource<NumberFormatter>

    let presenter: ReferendumVotersPresenterProtocol

    init(
        presenter: ReferendumVotersPresenterProtocol,
        votersType: ReferendumVotersType,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.votersType = votersType
        self.quantityFormatter = quantityFormatter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumVotersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureTableView()

        presenter.setup()
    }

    private func configureTableView() {
        rootView.tableView.registerClassForCell(ReferendumVotersTableViewCell.self)
        rootView.tableView.delegate = self

        dataSource = DataSource(
            tableView: rootView.tableView
        ) { tableView, _, viewModel in
            let cell = tableView.dequeueReusableCellWithType(ReferendumVotersTableViewCell.self)
            cell?.bind(viewModel: viewModel)
            return cell
        }
    }

    private func setupLocalization() {
        switch votersType {
        case .ayes:
            title = R.string.localizable.govVotersAye(preferredLanguages: selectedLocale.rLanguages)
        case .nays:
            title = R.string.localizable.govVotersNay(preferredLanguages: selectedLocale.rLanguages)
        }
    }

    private func setupCounter(value: Int?) {
        navigationItem.rightBarButtonItem = nil

        let formatter = quantityFormatter.value(for: selectedLocale)

        guard
            let value = value,
            let valueString = formatter.string(from: value as NSNumber) else {
            return
        }

        rootView.totalVotersLabel.titleLabel.text = valueString
        rootView.totalVotersLabel.sizeToFit()

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rootView.totalVotersLabel)
    }
}

extension ReferendumVotersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.selectVoter(at: indexPath.row)
    }
}

extension ReferendumVotersViewController: ReferendumVotersViewProtocol {
    func didReceiveViewModels(_ viewModels: LoadableViewModelState<[ReferendumVotersViewModel]>) {
        var snapshot = NSDiffableDataSourceSnapshot<String, ReferendumVotersViewModel>()

        switch viewModels {
        case let .loaded(value), let .cached(value):
            snapshot.reloadItems(value)

            setupCounter(value: value.count)
        case .loading:
            snapshot.reloadItems([])
            setupCounter(value: nil)
        }

        dataSource?.apply(snapshot, animatingDifferences: true)
    }
}

extension ReferendumVotersViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
