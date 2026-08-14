import UIKit
import UIKit_iOS

/// A checkbox next to a legal sentence containing two independently tappable links.
///
/// `CheckboxControlView` cannot be reused here: its base `ControlView` hard disables interaction on
/// the content view and exposes no escape hatch, so text inside it can never receive its own taps.
/// Here the checkbox and the text view are siblings: tapping a link opens a document, tapping the
/// surrounding text does nothing, and neither toggles the checkbox.
final class LegalConsentView: UIView {
    let checkboxControl = CheckboxHitControl()

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
    }
}

// MARK: - Private

private extension LegalConsentView {
    func setupLayout() {
        addSubview(checkboxControl)
        checkboxControl.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(Constants.checkboxSize)
            make.bottom.lessThanOrEqualToSuperview()
        }

        checkboxControl.addSubview(checkboxImageView)
        checkboxImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        textView.delegate = self

        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.leading.equalTo(checkboxControl.snp.trailing).offset(Constants.spacing)
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

// MARK: - CheckboxHitControl

/// The checkbox artwork is small, so the touch target is expanded without stealing taps from the
/// adjacent links.
final class CheckboxHitControl: UIControl {
    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds
            .insetBy(dx: -Constants.hitAreaInset, dy: -Constants.hitAreaInset)
            .contains(point)
    }
}

// MARK: - Constants

private extension CheckboxHitControl {
    enum Constants {
        static let hitAreaInset: CGFloat = 10.0
    }
}

private extension LegalConsentView {
    enum Constants {
        static let checkboxSize: CGFloat = 24.0
        static let spacing: CGFloat = 12.0
    }
}
