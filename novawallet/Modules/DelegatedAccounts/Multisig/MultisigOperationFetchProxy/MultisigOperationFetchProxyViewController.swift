import UIKit
import Foundation_iOS

final class MultisigOperationFetchProxyViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigOperationFetchProxyViewLayout

    let presenter: MultisigOperationFetchProxyPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        presenter: MultisigOperationFetchProxyPresenterProtocol,
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
        view = MultisigOperationFetchProxyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }
}

// MARK: - Private

private extension MultisigOperationFetchProxyViewController {
    func setupLocalization() {
        rootView.loadingView.titleLabel.text = R.string.localizable.multisigOperationLoadingPlaceholderText(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
    }
}

// MARK: - MultisigOperationFetchProxyViewProtocol

extension MultisigOperationFetchProxyViewController: MultisigOperationFetchProxyViewProtocol {
    func didReceive(loading: Bool) {
        loading ? didStartLoading() : didStopLoading()
    }
}

// MARK: - LoadableViewProtocol

extension MultisigOperationFetchProxyViewController: LoadableViewProtocol {
    func didStartLoading() {
        rootView.loadingView.start()
    }

    func didStopLoading() {
        rootView.loadingView.stop()
    }
}
