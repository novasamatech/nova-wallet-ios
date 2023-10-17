import SnapKit
import SoraUI

protocol SwapSlippageInputViewDelegateProtocol: AnyObject {
    func didSelect(percent: Percent, sender: Any?)
}

final class SwapSlippageInputView: BackgroundedContentControl {
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
        $0.clearButtonMode = .whileEditing
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

    weak var delegate: SwapSlippageInputViewDelegateProtocol?
    private(set) var inputViewModel: AmountInputViewModelProtocol?

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

    private var viewModel: [Percent] = []

    private func createButton(title: String) -> RoundedButton {
        let button = RoundedButton()
        button.applyAccessoryStyle()
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.imageWithTitleView?.title = title
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        return button
    }

    private func updateViewsVisablilty(for text: String?) {
        symbolLabel.isHidden = text.isNilOrEmpty
        buttonsStack.isHidden = !text.isNilOrEmpty
        setNeedsLayout()
        layoutIfNeeded()
    }
}

extension SwapSlippageInputView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let shouldChangeCharacters = inputViewModel?.didReceiveReplacement(string, for: range) ?? false
        updateViewsVisablilty(for: string)
        return shouldChangeCharacters
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        updateViewsVisablilty(for: "")

        return true
    }
}

extension SwapSlippageInputView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        textField.text = inputViewModel?.displayAmount
        updateViewsVisablilty(for: textField.text)

        sendActions(for: .editingChanged)
    }
}

extension SwapSlippageInputView {
    func bind(viewModel: [Percent]) {
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
        updateViewsVisablilty(for: textField.text)
    }
}