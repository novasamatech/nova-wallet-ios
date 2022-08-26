import UIKit
import SoraFoundation

final class LedgerPerformOperationViewController: UIViewController, ViewHolder {
    typealias RootViewType = LedgerPerformOperationViewLayout

    let presenter: LedgerPerformOperationPresenterProtocol

    private var networkName: String?

    init(presenter: LedgerPerformOperationPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LedgerPerformOperationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        updateActivityIndicator()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.headerView.valueTop.text = R.string.localizable.ledgerDiscoverTitle(preferredLanguages: languages)

        updateSubtitleLocalization()
    }

    private func updateSubtitleLocalization() {
        if let networkName = networkName {
            rootView.headerView.valueBottom.text = R.string.localizable.ledgerDiscoverDetails(
                networkName,
                preferredLanguages: selectedLocale.rLanguages
            )
        }
    }

    private func updateActivityIndicator() {
        let shouldAnimate = rootView.cells.isEmpty

        if shouldAnimate {
            rootView.activityIndicator.startAnimating()
        } else {
            rootView.activityIndicator.stopAnimating()
        }
    }

    @objc private func actionTap(_ sender: UIControl) {
        guard
            let cell = sender as? LoadableStackActionCell<UILabel>,
            let index = rootView.cells.firstIndex(of: cell) else {
            return
        }

        presenter.selectDevice(at: index)
    }
}

extension LedgerPerformOperationViewController: LedgerPerformOperationViewProtocol {
    func didReceive(networkName: String) {
        self.networkName = networkName

        updateSubtitleLocalization()
    }

    func didStartLoading(at index: Int) {
        rootView.cells[index].startLoading()
    }

    func didStopLoading(at index: Int) {
        rootView.cells[index].stopLoading()
    }

    func didReceive(devices: [String]) {
        rootView.clearCells()

        for device in devices {
            let cell = rootView.addCell(for: device)
            cell.addTarget(self, action: #selector(actionTap(_:)), for: .touchUpInside)
        }

        updateActivityIndicator()
    }
}

extension LedgerPerformOperationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
