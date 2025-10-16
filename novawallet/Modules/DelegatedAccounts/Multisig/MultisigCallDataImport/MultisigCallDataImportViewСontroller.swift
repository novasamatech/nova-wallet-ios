import UIKit
import UIKit_iOS
import Foundation_iOS

final class MultisigCallDataImportViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigCallDataImportViewLayout

    let presenter: MultisigCallDataImportPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    private let layoutChangeAnimator: BlockViewAnimatorProtocol

    init(
        presenter: MultisigCallDataImportPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        layoutChangeAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()
    ) {
        self.presenter = presenter
        self.layoutChangeAnimator = layoutChangeAnimator

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MultisigCallDataImportViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
        setupKeyboardHandler()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        rootView.callDataView.textView.becomeFirstResponder()
    }
}

// MARK: - Private

private extension MultisigCallDataImportViewController {
    func setupHandlers() {
        rootView.callDataView.addTarget(
            self,
            action: #selector(actionCallDataChanged),
            for: .editingChanged
        )
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionSave),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.enterCallData()

        applyActionStyle()
    }

    func applyActionStyle() {
        if let viewModel = rootView.callDataView.inputViewModel, viewModel.inputHandler.completed {
            rootView.actionButton.isEnabled = true
            rootView.actionButton.applyEnabledStyle()
            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonSave()
        } else {
            rootView.actionButton.isEnabled = false
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.enterCallData()
        }
    }

    @objc func actionCallDataChanged() {
        applyActionStyle()
    }

    @objc func actionSave() {
        presenter.save()
    }
}

// MARK: - MultisigCallDataImportViewProtocol

extension MultisigCallDataImportViewController: MultisigCallDataImportViewProtocol {
    func didReceive(callDataViewModel: InputViewModelProtocol) {
        rootView.callDataView.bind(inputViewModel: callDataViewModel)
    }
}

// MARK: - KeyboardAdoptable

extension MultisigCallDataImportViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY - rootView.safeAreaInsets.bottom
        let clampedBottomInset = max(bottomInset, 0)

        rootView.actionButton.snp.updateConstraints { make in
            make.bottom
                .equalTo(rootView.safeAreaLayoutGuide)
                .inset(UIConstants.actionBottomInset + clampedBottomInset)
        }

        layoutChangeAnimator.animate(
            block: { [weak self] in self?.rootView.layoutIfNeeded() },
            completionBlock: nil
        )
    }
}

// MARK: - Localizable

extension MultisigCallDataImportViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
