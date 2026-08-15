import UIKit
import UIKit_iOS

final class LegalConsentView: UIView {
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
        view.isSelectable = true
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
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

        checkboxControl.accessibilityLabel = agreement.string
    }
}

// MARK: - Private

private extension LegalConsentView {
    func setupLayout() {
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
