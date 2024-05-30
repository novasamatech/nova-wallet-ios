import UIKit

class MnemonicCardView: MnemonicGridView {
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
