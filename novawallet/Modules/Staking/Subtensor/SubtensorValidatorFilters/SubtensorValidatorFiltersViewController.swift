import UIKit
import Foundation_iOS

final class SubtensorValidatorFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorValidatorFiltersViewLayout
    let presenter: ValidatorFiltersPresenterProtocol
    private let sorts: [SubtensorValidatorSort] = [.apy, .totalStaked, .name]
    private var model: SubtensorValidatorFiltersViewModel?

    init(presenter: ValidatorFiltersPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SubtensorValidatorFiltersViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.tableView.registerClassForCell(SelectableFilterCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.applyButton.addTarget(self, action: #selector(apply), for: .touchUpInside)
        rootView.toggle.addTarget(self, action: #selector(toggleUnusualApy), for: .valueChanged)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: nil,
            style: .plain,
            target: self,
            action: #selector(reset)
        )
        applyLocalization()
        presenter.setup()
    }

    @objc private func apply() { presenter.apply() }
    @objc private func reset() { presenter.reset() }
    @objc private func toggleUnusualApy() { presenter.setHidesUnusualApy(rootView.toggle.isOn) }
}

extension SubtensorValidatorFiltersViewController: SubtensorValidatorFiltersViewProtocol {
    func didReceive(_ viewModel: SubtensorValidatorFiltersViewModel) {
        model = viewModel
        navigationItem.rightBarButtonItem?.isEnabled = viewModel.canReset
        rootView.toggle.isOn = viewModel.hidesUnusualApy
        rootView.applyButton.isEnabled = viewModel.canApply
        if viewModel.canApply {
            rootView.applyButton.applyEnabledStyle()
        } else {
            rootView.applyButton.applyDisabledStyle()
        }
        rootView.tableView.reloadData()
    }
}

extension SubtensorValidatorFiltersViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        title = strings.walletFiltersTitle()
        navigationItem.rightBarButtonItem?.title = strings.commonReset()
        rootView.showLabel.text = strings.stakingSubtensorV22Show()
        rootView.toggleTitle.text = strings.stakingSubtensorV22HideUnusual()
        rootView.toggleSubtitle.text = strings.stakingSubtensorV22FarAverage()
        rootView.sortLabel.text = strings.stakingSubtensorV22SortBy()
        rootView.applyButton.imageWithTitleView?.title = strings.commonApply()
        rootView.applyButton.invalidateLayout()
        rootView.tableView.reloadData()
    }
}

extension SubtensorValidatorFiltersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { sorts.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(SelectableFilterCell.self, forIndexPath: indexPath)
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        let titles = [
            strings.stakingValidatorApyPercent(),
            strings.stakingSubtensorV22TotalStaked(),
            strings.commonName()
        ]
        cell.titleLabel.apply(style: .regularBodyPrimary)
        cell.bind(viewModel: SelectableViewModel(
            underlyingViewModel: titles[indexPath.row],
            selectable: sorts[indexPath.row] == model?.selectedSort
        ))
        cell.contentView.alpha = indexPath.row == 0 ? 0.4 : 1
        cell.isUserInteractionEnabled = indexPath.row != 0
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectSort(sorts[indexPath.row])
    }
}
