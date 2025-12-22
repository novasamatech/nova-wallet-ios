import UIKit
import UIKit_iOS

class TextWithServiceInputView: TextInputView {
    let pasteboardService = PasteboardHandler(pasteboard: UIPasteboard.general)

    let pasteButton: RoundedButton = {
        let button = RoundedButton()
        button.applyAccessoryStyle()
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)
        button.imageWithTitleView?.titleFont = .semiBoldFootnote

        return button
    }()

    var locale = Locale.current {
        didSet {
            setupLocalization()
        }
    }

    override func configure() {
        super.configure()

        configurePasteHandlers()

        setupLocalization()
    }

    override func configureContentViewIfNeeded() {
        super.configureContentViewIfNeeded()

        stackView.addArrangedSubview(pasteButton)
    }

    func setupLocalization() {
        pasteButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonPaste()

        setNeedsLayout()
    }

    private func configurePasteHandlers() {
        pasteButton.addTarget(self, action: #selector(actionPaste), for: .touchUpInside)

        pasteboardService.delegate = self
    }

    override func applyingActionWidth(for currentWidth: CGFloat) -> CGFloat {
        let actionWidth = super.applyingActionWidth(for: currentWidth)

        if !pasteButton.isHidden {
            return actionWidth + pasteButton.intrinsicContentSize.width
        } else {
            return actionWidth
        }
    }

    override func applyControlsState() {
        if hasText, textField.isEnabled {
            clearButton.isHidden = false
            pasteButton.isHidden = true
        } else if !textField.isEnabled {
            clearButton.isHidden = true
            pasteButton.isHidden = true
        } else {
            clearButton.isHidden = true
            pasteButton.isHidden = !pasteboardService.pasteboard.hasStrings
        }
    }

    @objc func actionPaste() {
        if
            let pasteString = pasteboardService.pasteboard.string,
            let inputViewModel = inputViewModel,
            inputViewModel.inputHandler.value != pasteString {
            let currentValue = inputViewModel.inputHandler.value
            let currentLength = (currentValue as NSString).length
            let range = NSRange(location: 0, length: currentLength)

            _ = inputViewModel.inputHandler.didReceiveReplacement(pasteString, for: range)

            if currentValue != inputViewModel.inputHandler.value {
                textField.text = inputViewModel.inputHandler.value
                sendActions(for: .editingChanged)
            }

            updateControlsState()
        }
    }
}

extension TextWithServiceInputView: PasteboardHandlerDelegate {
    func didReceivePasteboardChange(notification _: Notification) {
        updateControlsState()
    }

    func didReceivePasteboardRemove(notification _: Notification) {
        updateControlsState()
    }
}
