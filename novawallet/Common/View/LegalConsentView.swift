import UIKit
import UIKit_iOS

/// A checkbox next to a legal sentence containing two independently tappable links.
///
/// `CheckboxControlView` cannot be reused here: its base `ControlView` hard disables interaction on
/// the content view and exposes no escape hatch, so text inside it can never receive its own taps.
/// Here the checkbox and the text view are siblings: tapping a link opens a document, tapping the
/// surrounding text does nothing, and neither toggles the checkbox.
final class LegalConsentView: UIView {
    /// The checkbox gates both welcome screen buttons and the accept button on the non dismissible
    /// sheet, so it has to be reachable by VoiceOver: the control carries the semantics, the image
    /// view inside it is decoration.
    let checkboxControl: UIControl = .create { view in
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
    }

    let checkboxImageView: UIImageView = .create { view in
        view.contentMode = .center
        view.isUserInteractionEnabled = false
    }

    let textView: LegalConsentTextView = .create { view in
        view.isScrollEnabled = false
        view.isEditable = false
        // Required for link hit testing. The selection menu is suppressed by the subclass.
        view.isSelectable = true
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        // Our own colour and underline attributes must win over UIKit's default link styling.
        view.linkTextAttributes = [:]
        view.textDragInteraction?.isEnabled = false
    }

    var onCheckboxToggle: (() -> Void)?
    var onLinkTap: ((LegalDocumentType) -> Void)?

    var isChecked: Bool = false {
        didSet {
            updateCheckboxState()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupHandlers()
        updateCheckboxState()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Bind

extension LegalConsentView {
    func bind(agreement: NSAttributedString) {
        textView.attributedText = agreement

        // The sentence is exactly what ticking the box commits to and it is already rendered for
        // the selected language, so it labels the control without a second string to translate.
        checkboxControl.accessibilityLabel = agreement.string
    }
}

// MARK: - Private

private extension LegalConsentView {
    func setupLayout() {
        // The artwork is small, so the control is grown to the 44pt minimum touch target and the
        // artwork is pinned to its top left corner. Growing the target around the artwork instead
        // would place it above and left of this view, outside the bounds our own superview hit
        // tests against, and those points would never reach the control.
        addSubview(checkboxControl)
        checkboxControl.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(Constants.checkboxTouchTarget)
            make.bottom.lessThanOrEqualToSuperview()
        }

        checkboxControl.addSubview(checkboxImageView)
        checkboxImageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(Constants.checkboxSize)
        }

        textView.delegate = self

        // Positioned off the artwork rather than off the control, so the sentence keeps sitting
        // 12pt from the tick and its first line keeps aligning with the top of the tick.
        // The text view is added last and therefore stays above the part of the target that runs
        // under it: taps on the copy keep doing nothing instead of toggling the checkbox.
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.leading.equalTo(checkboxImageView.snp.trailing).offset(Constants.spacing)
            make.top.trailing.bottom.equalToSuperview()
        }

        textView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    func setupHandlers() {
        checkboxControl.addTarget(self, action: #selector(actionCheckbox), for: .touchUpInside)
    }

    func updateCheckboxState() {
        checkboxImageView.image = isChecked
            ? R.image.iconCheckbox()
            : R.image.iconCheckboxEmpty()

        // VoiceOver speaks `.selected` itself, in its own language, so the tick state needs no
        // string of ours.
        checkboxControl.accessibilityTraits = isChecked ? [.button, .selected] : .button
    }

    @objc func actionCheckbox() {
        onCheckboxToggle?()
    }
}

// MARK: - UITextViewDelegate

extension LegalConsentView: UITextViewDelegate {
    func textView(
        _: UITextView,
        shouldInteractWith url: URL,
        in _: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        // Returning false for every interaction other than `.invokeDefaultAction` also suppresses
        // the long press link menu and the link preview, so "Open Link" can never bypass the
        // presenter route.
        guard interaction == .invokeDefaultAction else {
            return false
        }

        if let type = LegalDocumentType.fromLinkURL(url) {
            onLinkTap?(type)
        }

        return false
    }
}

// MARK: - LegalConsentTextView

/// `isSelectable` is mandatory for link taps but also enables the text selection edit menu. This
/// subclass suppresses the menu entirely: the sentence is legal copy, not user content.
final class LegalConsentTextView: UITextView {
    override func canPerformAction(_: Selector, withSender _: Any?) -> Bool {
        false
    }
}

// MARK: - Constants

private extension LegalConsentView {
    enum Constants {
        static let checkboxSize: CGFloat = 24.0
        static let checkboxTouchTarget: CGFloat = 44.0
        static let spacing: CGFloat = 12.0
    }
}
