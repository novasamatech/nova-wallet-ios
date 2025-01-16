import SnapKit
import UIKit_iOS

protocol PercentInputViewDelegateProtocol: AnyObject {
    func didSelect(percent: SlippagePercentViewModel, sender: Any?)
}

final class PercentInputView: BackgroundedContentControl {
    let textField: UITextField = .create {
        $0.font = UIFont.regularSubheadline
        $0.textColor = R.color.colorTextPrimary()
        $0.tintColor = R.color.colorTextPrimary()
        $0.textAlignment = .left

        $0.attributedPlaceholder = NSAttributedString(
            string: "0.5 %",
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        $0.keyboardType = .decimalPad
        $0.clearButtonMode = .always
    }

    let symbolLabel: UILabel = .create {
        $0.apply(style: .regularSubhedlinePrimary)
        $0.numberOfLines = 1
        $0.textAlignment = .left
        $0.text = "%"
        $0.isHidden = true
    }

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    var buttonsStack = UIView.hStack(
        alignment: .center,
        distribution: .equalSpacing,
        spacing: 8,
        []
    )

    weak var delegate: PercentInputViewDelegateProtocol?
    private(set) var inputViewModel: AmountInputViewModelProtocol?
    private var viewModel: [SlippagePercentViewModel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        configureBackgroundViewIfNeeded()
        configureContentView()
        setupTextFieldHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let textFieldWidth = max(availableWidth, 0)

        let textFieldHeight: CGFloat = textField.intrinsicContentSize.height

        textField.frame = CGRect(
            x: bounds.maxX - contentInsets.right - textFieldWidth,
            y: bounds.midY - textFieldHeight / 2,
            width: textFieldWidth,
            height: textFieldHeight
        )

        if !symbolLabel.isHidden {
            let text = textField.text ?? ""
            let texFieldContentSize = text.size(withAttributes: textField.typingAttributes)
            symbolLabel.frame = .init(
                x: textField.frame.minX + texFieldContentSize.width + 4,
                y: textField.frame.midY - symbolLabel.intrinsicContentSize.height / 2,
                width: symbolLabel.intrinsicContentSize.width,
                height: symbolLabel.intrinsicContentSize.height
            )
        } else {
            symbolLabel.frame = .zero
        }

        if !buttonsStack.isHidden, !buttonsStack.arrangedSubviews.isEmpty {
            var buttonsWidth: CGFloat = buttonsStack.arrangedSubviews.reduce(into: 0) {
                $0 = $0 + $1.intrinsicContentSize.width
            }
            buttonsWidth += CGFloat(buttonsStack.arrangedSubviews.count - 1) * 8
            let height: CGFloat = buttonsStack.arrangedSubviews.max(by: {
                $0.intrinsicContentSize.height > $1.intrinsicContentSize.height
            })?.intrinsicContentSize.height ?? 0
            let buttonStackX = bounds.maxX - contentInsets.right - buttonsWidth

            buttonsStack.frame = .init(
                x: buttonStackX,
                y: textField.frame.midY - height / 2,
                width: buttonsWidth,
                height: height
            )
        } else {
            buttonsStack.frame = .zero
        }

        backgroundView?.frame = bounds
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let roundedView = RoundedView()
            roundedView.apply(style: .strokeOnEditing)
            roundedView.isUserInteractionEnabled = false
            backgroundView = roundedView
        }
    }

    private func configureContentView() {
        addSubview(textField)
        addSubview(symbolLabel)
        addSubview(buttonsStack)
    }

    private func setupTextFieldHandlers() {
        textField.addTarget(self, action: #selector(editingDidBeginAction), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(editingDidEndAction), for: .editingDidEnd)
        textField.addTarget(self, action: #selector(editingDidEndAction), for: .editingDidEndOnExit)
        textField.delegate = self
    }

    @objc private func editingDidBeginAction() {
        buttonsStack.isHidden = true
        roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0.0
    }

    @objc private func editingDidEndAction() {
        if textField.text.isNilOrEmpty {
            buttonsStack.isHidden = false
        }
        roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0.0
    }

    @objc private func buttonAction(_ sender: RoundedButton) {
        guard let delegate = delegate else {
            return
        }
        if let index = buttonsStack.arrangedSubviews.firstIndex(where: { $0 === sender }),
           let buttonModel = viewModel[safe: index] {
            delegate.didSelect(percent: buttonModel, sender: self)
        }
    }

    private func createButton(title: String) -> RoundedButton {
        let button = RoundedButton()
        button.applyAccessoryStyle()
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.imageWithTitleView?.title = title
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        return button
    }

    private func updateViewsVisibility(for text: String?) {
        symbolLabel.isHidden = text.isNilOrEmpty
        buttonsStack.isHidden = !text.isNilOrEmpty
        textField.clearButtonMode = text.isNilOrEmpty ? .never : .always
        setNeedsLayout()
        layoutIfNeeded()
    }
}

extension PercentInputView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let shouldChangeCharacters = inputViewModel?.didReceiveReplacement(string, for: range) ?? false
        updateViewsVisibility(for: inputViewModel?.displayAmount)
        return shouldChangeCharacters
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        updateViewsVisibility(for: "")
        if let text = textField.text {
            inputViewModel?.didReceiveReplacement("", for: NSRange(location: 0, length: text.count))
            textField.text = ""
            return false
        }

        return true
    }
}

extension PercentInputView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        textField.text = inputViewModel?.displayAmount
        updateViewsVisibility(for: textField.text)

        sendActions(for: .editingChanged)
    }
}

extension PercentInputView {
    func bind(viewModel: [SlippagePercentViewModel]) {
        buttonsStack.arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }
        viewModel.forEach {
            buttonsStack.addArrangedSubview(
                createButton(title: $0.title)
            )
        }
        self.viewModel = viewModel
    }

    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)
        inputViewModel.observable.add(observer: self)

        self.inputViewModel = inputViewModel
        textField.text = inputViewModel.displayAmount
        updateViewsVisibility(for: textField.text)
    }
}

extension PercentInputView {
    enum Style {
        case error
        case normal
    }

    func apply(style: Style) {
        switch style {
        case .error:
            let color = R.color.colorTextNegative()!
            roundedBackgroundView?.strokeWidth = 0.5
            roundedBackgroundView?.strokeColor = color
            textField.textColor = color
            symbolLabel.textColor = color
        case .normal:
            roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0.0
            roundedBackgroundView?.strokeColor = R.color.colorActiveBorder()!
            textField.textColor = R.color.colorTextPrimary()
            symbolLabel.textColor = R.color.colorTextPrimary()
        }
    }
}
