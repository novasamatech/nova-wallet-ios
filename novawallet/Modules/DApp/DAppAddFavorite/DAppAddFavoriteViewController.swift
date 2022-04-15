import UIKit
import SoraFoundation

final class DAppAddFavoriteViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppAddFavoriteViewLayout

    let presenter: DAppAddFavoritePresenterProtocol

    var keyboardHandler: KeyboardHandler?

    private var titleViewModel: InputViewModelProtocol?
    private var addressViewModel: InputViewModelProtocol?

    init(presenter: DAppAddFavoritePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager

        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppAddFavoriteViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

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

    private func setupHandlers() {
        navigationItem.rightBarButtonItem = rootView.saveButton
        rootView.saveButton.target = self
        rootView.saveButton.action = #selector(actionSave)

        rootView.titleInputView.addTarget(self, action: #selector(actionFieldChange), for: .editingChanged)
        rootView.addressInputView.addTarget(self, action: #selector(actionFieldChange), for: .editingChanged)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.dappFavoriteAddTitle(preferredLanguages: languages)

        rootView.saveButton.title = R.string.localizable.commonSave(preferredLanguages: languages)
        rootView.titleLabel.text = R.string.localizable.commonTitle(preferredLanguages: languages)
        rootView.addressLabel.text = R.string.localizable.commonAddress(preferredLanguages: languages)
    }

    private func updateSaveButton() {
        if
            let titleViewModel = titleViewModel, titleViewModel.inputHandler.completed,
            let addressViewModel = addressViewModel, addressViewModel.inputHandler.completed {
            rootView.saveButton.isEnabled = true
        } else {
            rootView.saveButton.isEnabled = false
        }
    }

    @objc private func actionFieldChange() {
        updateSaveButton()
    }

    @objc private func actionSave() {
        presenter.save()
    }
}

extension DAppAddFavoriteViewController: DAppAddFavoriteViewProtocol {
    func didReceive(iconViewModel: ImageViewModelProtocol) {
        let size = DAppAddFavoriteViewLayout.Constants.iconDisplaySize
        rootView.iconView.bind(viewModel: iconViewModel, size: size)
    }

    func didReceive(titleViewModel: InputViewModelProtocol) {
        self.titleViewModel = titleViewModel

        rootView.titleInputView.bind(inputViewModel: titleViewModel)

        updateSaveButton()
    }

    func didReceive(addressViewModel: InputViewModelProtocol) {
        self.addressViewModel = addressViewModel

        rootView.addressInputView.bind(inputViewModel: addressViewModel)

        updateSaveButton()
    }
}

extension DAppAddFavoriteViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if rootView.titleInputView.isFirstResponder {
                targetView = rootView.titleInputView
            } else if rootView.addressInputView.isFirstResponder {
                targetView = rootView.addressInputView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

extension DAppAddFavoriteViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
