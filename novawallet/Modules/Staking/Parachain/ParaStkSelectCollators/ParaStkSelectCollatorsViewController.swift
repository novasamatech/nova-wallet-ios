import UIKit
import SoraFoundation

final class ParaStkSelectCollatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParaStkSelectCollatorsViewLayout

    let presenter: ParaStkSelectCollatorsPresenterProtocol

    private var viewModel: [CollatorSelectionViewModel] = []
    private var sorting = CollatorsSortType.rewards
    private var headerViewModel: TitleWithSubtitleViewModel?

    init(
        presenter: ParaStkSelectCollatorsPresenterProtocol,
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
        view = ParaStkSelectCollatorsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBarItems()
        setupLocalization()

        presenter.setup()
    }

    private func setupBarItems() {
        navigationItem.rightBarButtonItems = [rootView.searchButton, rootView.filterButton]

        rootView.searchButton.target = self
        rootView.searchButton.action = #selector(actionSearch)

        rootView.filterButton.target = self
        rootView.filterButton.action = #selector(actionFilter)
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(CollatorSelectionCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
    }

    private func setupLocalization() {
        title = R.string.localizable.parachainStakingSelectCollator(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.clearButton.imageWithTitleView?.title = R.string.localizable.stakingCustomClearButtonTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.clearButton.invalidateLayout()
    }

    @objc private func actionSearch() {}

    @objc private func actionFilter() {}
}

// MARK: - UITableViewDelegate

extension ParaStkSelectCollatorsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard headerViewModel != nil else { return 0 }
        return 26.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let headerViewModel = headerViewModel else { return nil }
        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(viewModel: headerViewModel)
        return headerView
    }
}

// MARK: - CustomValidatorCellDelegate

extension ParaStkSelectCollatorsViewController: CustomValidatorCellDelegate {
    func didTapInfoButton(in cell: CustomValidatorCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            presentValidatorInfo(at: indexPath.row)
        }
    }
}

extension ParaStkSelectCollatorsViewController: ParaStkSelectCollatorsViewProtocol {}

extension ParaStkSelectCollatorsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
