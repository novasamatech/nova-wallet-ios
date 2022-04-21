import UIKit
import SoraUI
import SoraFoundation

class TextInputField: BackgroundedContentControl {
    let textField: UITextField = {
        let textField = UITextField()
        textField.font = .regularSubheadline
        textField.textColor = R.color.colorWhite()
        textField.tintColor = R.color.colorWhite()
        textField.returnKeyType = .done

        return textField
    }()

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 48.0)
    }

    private(set) var inputViewModel: InputViewModelProtocol?

    var completed: Bool {
        if let inputViewModel = inputViewModel {
            return inputViewModel.inputHandler.completed
        } else {
            return false
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    override func becomeFirstResponder() -> Bool {
        textField.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        textField.resignFirstResponder()
    }

    override var isFirstResponder: Bool { textField.isFirstResponder }

    func bind(inputViewModel: InputViewModelProtocol) {
        self.inputViewModel = inputViewModel

        textField.text = inputViewModel.inputHandler.value

        setNeedsLayout()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutContent()
    }

    private func layoutContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right

        let fieldHeight = bounds.height - contentInsets.top - contentInsets.bottom

        textField.frame = CGRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: availableWidth,
            height: fieldHeight
        )
    }

    // MARK: Configure

    private func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        configureTextFieldHandlers()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let roundedView = RoundedView()
            roundedView.isUserInteractionEnabled = false
            roundedView.shadowOpacity = 0.0
            roundedView.strokeColor = R.color.colorAccent()!
            roundedView.fillColor = R.color.colorWhite8()!
            roundedView.highlightedFillColor = R.color.colorWhite8()!
            roundedView.strokeWidth = 0.0
            roundedView.cornerRadius = 12.0

            backgroundView = roundedView
        }
    }

    private func configureTextFieldHandlers() {
        textField.delegate = self

        textField.addTarget(
            self,
            action: #selector(actionEditingDidBeginEnd),
            for: .editingDidBegin
        )

        textField.addTarget(
            self,
            action: #selector(actionEditingDidBeginEnd),
            for: .editingDidEnd
        )

        textField.addTarget(
            self,
            action: #selector(actionEditingChanged),
            for: .editingChanged
        )
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            contentView = textField
            contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)
        }
    }

    private func updateTextFieldState() {
        if textField.isFirstResponder {
            roundedBackgroundView?.strokeWidth = 0.5
        } else {
            roundedBackgroundView?.strokeWidth = 0.0
        }
    }

    // MARK: Action

    @objc private func actionEditingChanged() {
        if
            let inputViewModel = inputViewModel,
            textField.text != inputViewModel.inputHandler.value {
            textField.text = inputViewModel.inputHandler.value

            sendActions(for: .editingChanged)
        }
    }

    @objc private func actionEditingDidBeginEnd() {
        updateTextFieldState()
    }
}

extension TextInputField: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.inputHandler.didReceiveReplacement(string, for: range) ?? false
    }
}
