import Foundation_iOS
import UIKit

final class SubtensorSubnetSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSubnetSelectViewLayout

    let presenter: SubtensorSubnetSelectPresenterProtocol

    private var viewModels: [SubtensorSubnetSelectViewModel] = []

    init(
        presenter: SubtensorSubnetSelectPresenterProtocol,
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
        view = SubtensorSubnetSelectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSearchField()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }
}

private extension SubtensorSubnetSelectViewController {
    func setupSearchField() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )
    }

    func setupTableView() {
        rootView.tableView.rowHeight = 56
        rootView.tableView.registerClassForCell(SubtensorSubnetCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        title = strings.stakingSubtensorSubnetSelectTitle()

        rootView.disclaimerLabel.text = strings.stakingSubtensorSubnetAprDisclaimer()

        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: strings.stakingSubtensorSubnetSearchPlaceholder(),
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorHintText()!
            ]
        )
    }

    @objc func actionSearchEditingChanged() {
        presenter.search(query: rootView.searchTextField.text ?? "")
    }
}

extension SubtensorSubnetSelectViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(SubtensorSubnetCell.self)!

        cell.bind(viewModel: viewModels[indexPath.row])

        return cell
    }
}

extension SubtensorSubnetSelectViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.select(viewModel: viewModels[indexPath.row])
    }
}

extension SubtensorSubnetSelectViewController: SubtensorSubnetSelectViewProtocol {
    func didReceive(viewModels: [SubtensorSubnetSelectViewModel]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
    }
}

extension SubtensorSubnetSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
