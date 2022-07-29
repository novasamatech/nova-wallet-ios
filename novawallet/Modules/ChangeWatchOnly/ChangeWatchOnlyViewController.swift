import UIKit
import SoraFoundation

final class ChangeWatchOnlyViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChangeWatchOnlyViewLayout

    var keyboardHandler: KeyboardHandler?

    let presenter: ChangeWatchOnlyPresenterProtocol

    init(presenter: ChangeWatchOnlyPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChangeWatchOnlyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        updateActionButtonState()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.accountActionsChangeTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.detailsLabel.text = R.string.localizable.watchOnlyAccountChangeDetails(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupHandlers() {
        rootView.addressInputView.addTarget(
            self,
            action: #selector(actionAddressChanged),
            for: .editingChanged
        )

        rootView.actionButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )

        rootView.addressInputView.scanButton.addTarget(
            self,
            action: #selector(actionScan),
            for: .touchUpInside
        )
    }

    private func updateActionButtonState() {
        if !rootView.addressInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.transferSetupEnterAddress(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.actionButton.invalidateLayout()
        } else {
            rootView.actionButton.applyEnabledStyle()
            rootView.actionButton.isUserInteractionEnabled = true

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.actionButton.invalidateLayout()
        }
    }

    @objc private func actionAddressChanged() {
        let partialAddress = rootView.addressInputView.textField.text ?? ""
        presenter.updateAddress(partialAddress)

        updateActionButtonState()
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    @objc private func actionScan() {
        presenter.performScan()
    }
}

extension ChangeWatchOnlyViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView = rootView.addressInputView

            let fieldFrame = scrollView.convert(
                targetView.frame,
                from: targetView.superview
            )

            scrollView.scrollRectToVisible(fieldFrame, animated: true)
        }
    }
}

extension ChangeWatchOnlyViewController: ChangeWatchOnlyViewProtocol {
    func didReceiveAddressState(viewModel: AccountFieldStateViewModel) {
        rootView.addressInputView.bind(fieldStateViewModel: viewModel)
    }

    func didReceiveAddressInput(viewModel: InputViewModelProtocol) {
        rootView.addressInputView.bind(inputViewModel: viewModel)

        updateActionButtonState()
    }
}

extension ChangeWatchOnlyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
