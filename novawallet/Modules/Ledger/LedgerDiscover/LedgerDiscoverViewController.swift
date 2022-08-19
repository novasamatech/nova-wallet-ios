import UIKit
import SoraFoundation

final class LedgerDiscoverViewController: UIViewController, ViewHolder {
    typealias RootViewType = LedgerDiscoverViewLayout

    let presenter: LedgerDiscoverPresenterProtocol

    init(presenter: LedgerDiscoverPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LedgerDiscoverViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.headerView.valueTop.text = R.string.localizable.ledgerDiscoverTitle(preferredLanguages: languages)
        rootView.headerView.valueBottom.text = R.string.localizable.ledgerDiscoverDetails(preferredLanguages: languages)
    }

    @objc private func actionTap(_ sender: UIControl) {
        guard let index = rootView.deviceTableView.stackView.arrangedSubviews.firstIndex(of: sender) else {
            return
        }

        presenter.selectDevice(at: index)
    }
}

extension LedgerDiscoverViewController: LedgerDiscoverViewProtocol {
    func didReceive(devices: [String]) {
        rootView.deviceTableView.clear()

        for device in devices {
            let cell = StackActionCell()
            rootView.deviceTableView.addArrangedSubview(cell)

            cell.bind(title: device, icon: nil, details: nil)

            cell.addTarget(self, action: #selector(actionTap(_:)), for: .touchUpInside)
        }
    }
}

extension LedgerDiscoverViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
