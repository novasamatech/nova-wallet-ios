import UIKit
import Foundation_iOS

final class SwapTokenSelectNetworksViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapTokenSelectNetworksViewLayout

    let presenter: SwapTokenSelectNetworksPresenterProtocol

    private var viewModels: [SwapTokenSelectNetworkViewModel] = []

    init(presenter: SwapTokenSelectNetworksPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapTokenSelectNetworksViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()

        rootView.doneButton.addTarget(self, action: #selector(actionDone), for: .touchUpInside)

        presenter.setup()
    }
}

// MARK: Private

private extension SwapTokenSelectNetworksViewController {
    func setupTableView() {
        rootView.tableView.registerClassForCell(SwapTokenSelectNetworkCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        rootView.titleLabel.text = strings.commonSelectNetwork()
        rootView.doneButton.imageWithTitleView?.title = strings.commonDone()
        rootView.doneButton.invalidateLayout()
    }

    @objc func actionDone() {
        presenter.confirm()
    }
}

// MARK: SwapTokenSelectNetworksViewProtocol

extension SwapTokenSelectNetworksViewController: SwapTokenSelectNetworksViewProtocol {
    func didReceive(viewModels: [SwapTokenSelectNetworkViewModel]) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()
    }
}

// MARK: UITableViewDataSource

extension SwapTokenSelectNetworksViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(SwapTokenSelectNetworkCell.self, forIndexPath: indexPath)
        cell.bind(viewModel: viewModels[indexPath.row])
        return cell
    }
}

// MARK: UITableViewDelegate

extension SwapTokenSelectNetworksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.toggleNetwork(at: indexPath.row)
    }
}

// MARK: Localizable

extension SwapTokenSelectNetworksViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
