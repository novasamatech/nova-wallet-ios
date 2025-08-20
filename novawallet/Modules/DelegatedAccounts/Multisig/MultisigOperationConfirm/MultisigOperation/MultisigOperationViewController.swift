import UIKit
import Foundation_iOS

final class MultisigOperationViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigOperationViewLayout

    let presenter: MultisigOperationPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        presenter: MultisigOperationPresenterProtocol,
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
        view = MultisigOperationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }
}

// MARK: - Private

private extension MultisigOperationViewController {
    func setupLocalization() {
        rootView.loadingView.titleLabel.text = R.string.localizable.multisigOperationLoadingPlaceholderText(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
    }
}

// MARK: - MultisigOperationViewProtocol

extension MultisigOperationViewController: MultisigOperationViewProtocol {
    func didReceive(loading: Bool) {
        loading ? didStartLoading() : didStopLoading()
    }
}

// MARK: - LoadableViewProtocol

extension MultisigOperationViewController: LoadableViewProtocol {
    func didStartLoading() {
        rootView.loadingView.start()
    }

    func didStopLoading() {
        rootView.loadingView.stop()
    }
}
