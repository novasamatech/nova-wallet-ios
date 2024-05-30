import UIKit

final class MnemonicCardView: MnemonicGridView {
    let cardTitleView: UILabel = .create { view in
        view.apply(style: .semiboldSubhedlineSecondary)
        view.textAlignment = .left
    }

    let backgroundView: UIImageView = .create { view in
        view.image = R.image.cardBg()
        view.contentMode = .scaleToFill
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    override func setupLayout() {
        super.setupLayout()

        spacing = Constants.itemsSpacing
        contentInset = Constants.contentInset
        stackView.addArrangedSubview(cardTitleView)
        stackView.setCustomSpacing(
            Constants.titleBottomOffset,
            after: cardTitleView
        )

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(stackView)
            make.height.equalTo(stackView)
        }

        bringSubviewToFront(stackView)
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundView.layer.cornerRadius = Constants.cardCornerRadius
        backgroundView.clipsToBounds = true
        backgroundView.layer.borderWidth = 1.0
        backgroundView.layer.borderColor = R.color.colorContainerBorder()?.cgColor
    }

    override func createWordButton(
        with text: String,
        number: Int
    ) -> WordButton {
        let button = super.createWordButton(with: text, number: number)

        button.controlContentView.textAlignment = .left
        button.controlContentView.attributedText = createButtonText(with: number, text)

        return button
    }

    override func processInsertedButton(
        _ wordButton: WordButton,
        wordText: String
    ) {
        UIView.animate(withDuration: 0.2) {
            wordButton.controlContentView.alpha = 0
        } completion: { _ in
            let wordNumber = wordButton.tag + 1

            wordButton.controlContentView.textAlignment = .left
            wordButton.controlContentView.attributedText = createButtonText(with: wordNumber, wordText)

            UIView.animate(withDuration: 0.2) {
                wordButton.controlContentView.alpha = 1
            }
        }
    }

    func bind(to model: Model) {
        cardTitleView.attributedText = model.title
        bind(with: model.units)
    }
}

extension MnemonicCardView {
    struct Model {
        let units: [MnemonicGridView.UnitType]
        let title: NSAttributedString
    }
}

private extension MnemonicCardView {
    
    func createButtonText(
        with wordNumber: Int,
        _ text: String
    ) -> NSAttributedString {
        NSAttributedString.coloredItems(
            ["\(wordNumber)"],
            formattingClosure: { String(format: "%@ \(text)", $0[0]) },
            color: R.color.colorTextSecondary()!
        )
    }
}

private extension MnemonicCardView {
    enum Constants {
        static let titleBottomOffset: CGFloat = 12
        static let itemsSpacing: CGFloat = 4
        static let cardCornerRadius: CGFloat = 12.0
        static let contentInset: UIEdgeInsets = .init(
            top: 12,
            left: 12,
            bottom: 12,
            right: 12
        )
    }
}
