import UIKit
import SoraFoundation

final class ImportCloudPasswordViewController: UIViewController, ViewHolder {
    typealias RootViewType = ImportCloudPasswordViewLayout

    let presenter: ImportCloudPasswordPresenterProtocol

    init(presenter: ImportCloudPasswordPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ImportCloudPasswordViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(self, action: #selector(actionContinue), for: .touchUpInside)
    }
    
    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.cloudBackupImportTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        
        rootView.subtitleLabel.text = R.string.localizable.cloudBackupImportSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        
        rootView.forgetPasswordButton.imageWithTitleView?.title = R.string.localizable.commonForgotPasswordButton(
            preferredLanguages: selectedLocale.rLanguages
        )
        
        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue()
    }
    
    @objc func actionContinue() {
        presenter.activateContinue()
    }
}

extension ImportCloudPasswordViewController: ImportCloudPasswordViewProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol) {
        rootView.passwordView.bind(inputViewModel: passwordViewModel)
    }
}

extension ImportCloudPasswordViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
