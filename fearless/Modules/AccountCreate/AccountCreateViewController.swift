import UIKit
import SoraFoundation
import SoraUI

final class AccountCreateViewController: UIViewController {
    var presenter: AccountCreatePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var expandableControl: ExpandableActionControl!
    @IBOutlet private var detailsLabel: UILabel!

    @IBOutlet var substrateCryptoTypeView: BorderedSubtitleActionView!
    @IBOutlet var ethereumCryptoTypeView: BorderedSubtitleActionView!

    @IBOutlet var substrateDerivationPathView: UIView!
    @IBOutlet var substrateDerivationPathLabel: UILabel!
    @IBOutlet var substrateDerivationPathField: UITextField!
    @IBOutlet var substrateDerivationPathImageView: UIImageView!

    @IBOutlet var ethereumDerivationPathView: UIView!
    @IBOutlet var ethereumDerivationPathLabel: UILabel!
    @IBOutlet var ethereumDerivationPathField: UITextField!
    @IBOutlet var ethereumDerivationPathImageView: UIImageView!

    @IBOutlet var advancedContainerView: UIView!
    @IBOutlet var advancedControl: ExpandableActionControl!

    @IBOutlet var nextButton: TriangularedButton!

    private var substrateDerivationPathModel: InputViewModelProtocol?
    private var ethereumDerivationPathModel: InputViewModelProtocol?

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromBottom,
        curve: .easeOut
    )

    var advancedDismissalAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromTop,
        curve: .easeIn
    )

    private var mnemonicView: MnemonicDisplayView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupLocalization()
        configure()

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

    // MARK: - Configuration

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }

        advancedContainerView.isHidden = !expandableControl.isActivated

        substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenCryptoType),
            for: .valueChanged
        )

        ethereumCryptoTypeView.actionControl.showsImageIndicator = false
        ethereumCryptoTypeView.applyDisabledStyle()

        substrateCryptoTypeView.isHidden = false
        ethereumCryptoTypeView.isHidden = false
        substrateDerivationPathView.isHidden = false
        ethereumDerivationPathView.isHidden = false
    }

    private func setupNavigationItem() {
        let infoItem = UIBarButtonItem(
            image: R.image.iconInfo(),
            style: .plain,
            target: self,
            action: #selector(actionOpenInfo)
        )
        navigationItem.rightBarButtonItem = infoItem
    }

    private func setupMnemonicViewIfNeeded() {
        guard mnemonicView == nil else {
            return
        }

        let mnemonicView = MnemonicDisplayView()

        if let indexColor = R.color.colorGray() {
            mnemonicView.indexTitleColorInColumn = indexColor
        }

        if let titleColor = R.color.colorWhite() {
            mnemonicView.wordTitleColorInColumn = titleColor
        }

        mnemonicView.indexFontInColumn = .p0Digits
        mnemonicView.wordFontInColumn = .p0Paragraph
        mnemonicView.backgroundColor = R.color.colorBlack()

        stackView.insertArrangedSubview(mnemonicView, at: 1)

        self.mnemonicView = mnemonicView
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.accountCreateTitle(preferredLanguages: locale.rLanguages)
        detailsLabel.text = R.string.localizable.accountCreateDetails(preferredLanguages: locale.rLanguages)

        advancedControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)
        advancedControl.invalidateLayout()

        substrateCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonCryptoTypeSubstrate(preferredLanguages: locale.rLanguages)
        substrateCryptoTypeView.actionControl.invalidateLayout()

        ethereumCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonCryptoTypeEthereum(preferredLanguages: locale.rLanguages)
        ethereumCryptoTypeView.actionControl.invalidateLayout()

        substrateDerivationPathLabel.text = R.string.localizable
            .commonSecretDerivationPathSubstrate(preferredLanguages: locale.rLanguages)
        ethereumDerivationPathLabel.text = R.string.localizable
            .commonSecretDerivationPathEthereum(preferredLanguages: locale.rLanguages)

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()
    }

    // MARK: - Derivation path processing

    private func updateSubstrateDerivationPath(status: FieldStatus) {
        substrateDerivationPathImageView.image = status.icon
    }

    private func updateEthereumDerivationPath(status: FieldStatus) {
        ethereumDerivationPathImageView.image = status.icon
    }

    private func setDerivationPath(viewModel: InputViewModelProtocol, for textField: UITextField) {
        textField.text = viewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: viewModel.placeholder,
            attributes: [.foregroundColor: R.color.colorGray()!]
        )

        textField.attributedPlaceholder = attributedPlaceholder
    }

    private func updateSubstrateTextField() {
        if substrateDerivationPathModel?.inputHandler.value != substrateDerivationPathField.text {
            substrateDerivationPathField.text = substrateDerivationPathModel?.inputHandler.value
        }
    }

    private func updateEthereumTextField() {
        if ethereumDerivationPathModel?.inputHandler.value != ethereumDerivationPathField.text {
            ethereumDerivationPathField.text = ethereumDerivationPathModel?.inputHandler.value
        }
    }

    // MARK: - Actions

    @IBAction private func actionExpand() {
        stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !expandableControl.isActivated

        if expandableControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            substrateDerivationPathField.resignFirstResponder()
            ethereumDerivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }

    @IBAction func actionTextFieldEditingChanged(_ sender: UITextField) {
        if sender == substrateDerivationPathField {
            updateSubstrateTextField()
        } else {
            updateEthereumTextField()
        }
    }

    @objc private func actionOpenCryptoType() {
        if substrateCryptoTypeView.actionControl.isActivated {
            presenter.selectCryptoType()
        }
    }

    @objc private func actionOpenInfo() {
        presenter.activateInfo()
    }
}

// MARK: - AccountCreateViewProtocol

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        setupMnemonicViewIfNeeded()

        mnemonicView?.bind(words: mnemonic, columnsCount: 2)
    }

    func setSelectedCrypto(model: TitleWithSubtitleViewModel) {
        let title = "\(model.title) | \(model.subtitle)"

        substrateCryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        substrateCryptoTypeView.actionControl.invalidateLayout()
    }

    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol?) {
        guard let viewModel = viewModel else {
            substrateCryptoTypeView.isHidden = true
            substrateDerivationPathView.isHidden = true

            return
        }

        substrateDerivationPathModel = viewModel
        setDerivationPath(viewModel: viewModel, for: substrateDerivationPathField)
    }

    func setEthereumDerivationPath(viewModel: InputViewModelProtocol?) {
        guard let viewModel = viewModel else {
            ethereumCryptoTypeView.isHidden = true
            ethereumDerivationPathView.isHidden = true

            return
        }

        ethereumDerivationPathModel = viewModel
        setDerivationPath(viewModel: viewModel, for: ethereumDerivationPathField)
    }

    func didCompleteCryptoTypeSelection() {
        substrateCryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didValidateSubstrateDerivationPath(_ status: FieldStatus) {
        updateSubstrateDerivationPath(status: status)
    }

    func didValidateEthereumDerivationPath(_ status: FieldStatus) {
        updateEthereumDerivationPath(status: status)
    }
}

// MARK: - UITextFieldDelegate

extension AccountCreateViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        presenter.validate()

        return false
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let maybeViewModel = textField == substrateDerivationPathField ?
            substrateDerivationPathModel : ethereumDerivationPathModel

        guard let viewModel = maybeViewModel else { return true }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}

// MARK: - KeyboardAdoptable

extension AccountCreateViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let fieldFrame = scrollView.convert(
                substrateCryptoTypeView.frame,
                from: substrateCryptoTypeView.superview
            )

            scrollView.scrollRectToVisible(fieldFrame, animated: true)
        }
    }
}

// MARK: - Localizable

extension AccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
