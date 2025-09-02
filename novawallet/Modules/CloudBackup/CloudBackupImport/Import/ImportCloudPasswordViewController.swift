import UIKit
import Foundation_iOS

final class ImportCloudPasswordViewController: UIViewController, ViewHolder {
    typealias RootViewType = ImportCloudPasswordViewLayout

    let presenter: ImportCloudPasswordPresenterProtocol

    let flow: EnterBackupPasswordFlow

    init(
        presenter: ImportCloudPasswordPresenterProtocol,
        flow: EnterBackupPasswordFlow,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.flow = flow

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        rootView.passwordView.textField.becomeFirstResponder()
    }

    private func setupHandlers() {
        rootView.forgetPasswordButton.addTarget(self, action: #selector(actionForgotPassword), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(actionContinue), for: .touchUpInside)
        rootView.passwordView.addTarget(self, action: #selector(actionPasswordChanged), for: .editingChanged)
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.cloudBackupImportTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        switch flow {
        case .importBackup, .changePassword:
            rootView.subtitleLabel.text = R.string.localizable.cloudBackupImportSubtitle(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .enterPassword:
            rootView.subtitleLabel.text = R.string.localizable.cloudBackupEnterPasswordSetMessage(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        let passwordPlaceholder = NSAttributedString(
            string: R.string.localizable.commonBackupPassword(preferredLanguages: selectedLocale.rLanguages),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.passwordView.textField.attributedPlaceholder = passwordPlaceholder

        rootView.forgetPasswordButton.imageWithTitleView?.title = R.string.localizable.commonForgotPasswordButton(
            preferredLanguages: selectedLocale.rLanguages
        )

        applyActionStyle()
    }

    private func applyActionStyle() {
        if let viewModel = rootView.passwordView.inputViewModel, viewModel.inputHandler.completed {
            rootView.actionButton.isEnabled = true
            rootView.actionButton.applyEnabledStyle()
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            rootView.actionButton.isEnabled = false
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonEnterPassword(
                preferredLanguages: selectedLocale.rLanguages
            )
        }
    }

    @objc func actionContinue() {
        presenter.activateContinue()
    }

    @objc func actionForgotPassword() {
        presenter.activateForgotPassword()
    }

    @objc func actionPasswordChanged() {
        applyActionStyle()
    }
}

extension ImportCloudPasswordViewController: ImportCloudPasswordViewProtocol {
    func didReceive(flow _: EnterBackupPasswordFlow) {}

    func didReceive(passwordViewModel: InputViewModelProtocol) {
        rootView.passwordView.bind(inputViewModel: passwordViewModel)
    }

    func didStartLoading() {
        rootView.containerView.isUserInteractionEnabled = false
        rootView.genericActionView.startLoading()
    }

    func didStopLoading() {
        rootView.containerView.isUserInteractionEnabled = true
        rootView.genericActionView.stopLoading()
    }
}

extension ImportCloudPasswordViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
