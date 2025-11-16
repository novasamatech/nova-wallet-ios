import UIKit
import Foundation_iOS

final class GiftHistoryCheckViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftHistoryCheckViewLayout

    let presenter: GiftHistoryCheckPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        presenter: GiftHistoryCheckPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftHistoryCheckViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }
}

// MARK: - Private

private extension GiftHistoryCheckViewController {
    func setupLocalization() {
        rootView.loadingView.titleLabel.text = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.multisigOperationLoadingPlaceholderText()
    }
}

// MARK: - MultisigOperationFetchProxyViewProtocol

extension GiftHistoryCheckViewController: MultisigOperationFetchProxyViewProtocol {
    func didReceive(loading: Bool) {
        loading ? didStartLoading() : didStopLoading()
    }
}

// MARK: - LoadableViewProtocol

extension GiftHistoryCheckViewController: LoadableViewProtocol {
    func didStartLoading() {
        rootView.loadingView.start()
    }

    func didStopLoading() {
        rootView.loadingView.stop()
    }
}
