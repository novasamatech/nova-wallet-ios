import SnapKit
import SoraUI

protocol SwapSlippageInputViewDelegateProtocol: AnyObject {
    func didSelect(percent: Percent, sender: Any?)
}

final class SwapSlippageInputView: BackgroundedContentControl {
    let textField: UITextField = .create {
        $0.font = .title2
        $0.textColor = R.color.colorTextPrimary()
        $0.tintColor = R.color.colorTextPrimary()
        $0.textAlignment = .left

        $0.attributedPlaceholder = NSAttributedString(
            string: "0.5 %",
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.title2
            ]
        )

        $0.keyboardType = .decimalPad
        $0.clearButtonMode = .whileEditing
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
        setupLayout()
        configureBackgroundViewIfNeeded()
        setupTextFieldHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(textField)
        textField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.top.bottom.equalToSuperview().inset(14)
        }
        addSubview(buttonsStack)
        buttonsStack.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(12)
            $0.top.bottom.equalToSuperview().inset(8)
            $0.width.lessThanOrEqualToSuperview().multipliedBy(0.7)
        }
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let roundedView = RoundedView()
            roundedView.apply(style: .strokeOnEditing)
            roundedView.isUserInteractionEnabled = false
            backgroundView = roundedView
        }
    }

    private func setupTextFieldHandlers() {
        textField.addTarget(self, action: #selector(editingDidChangeAction), for: .editingChanged)
        textField.addTarget(self, action: #selector(editingDidBeginAction), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(editingDidEndAction), for: .editingDidEnd)
        textField.addTarget(self, action: #selector(editingDidEndAction), for: .editingDidEndOnExit)
        textField.delegate = self
    }

    @objc private func editingDidBeginAction() {
        buttonsStack.isHidden = true
        roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0.0
    }

    @objc private func editingDidChangeAction() {
        buttonsStack.isHidden = true
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
        if let index = buttonsStack.arrangedSubviews.index(where: { $0 === sender }),
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
}

extension SwapSlippageInputView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let offset = inputViewModel?.currentOffset,
           let position = textField.position(from: textField.beginningOfDocument, offset: offset) {
            textField.selectedTextRange = textField.textRange(
                from: textField.beginningOfDocument,
                to: position
            )
        }
    }
}

extension SwapSlippageInputView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        textField.text = inputViewModel?.displayAmount

        if textField.isEditing {
            sendActions(for: .editingChanged)
        }
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
    }
}
