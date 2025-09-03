import UIKit

final class CurrencyCollectionViewCell: UICollectionViewCell {
    private let symbolLabel: BorderedLabelView = .create {
        $0.titleLabel.textAlignment = .center
        $0.titleLabel.font = .systemFont(ofSize: 13)
        $0.titleLabel.textColor = R.color.colorTextSecondary()
        $0.contentInsets = Constants.Symbol.contentInsets
        $0.backgroundView.apply(style: .roundedContainer(radius: Constants.Symbol.cornerRadius))
    }

    private let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorTextPrimary()
        $0.font = .regularSubheadline
        $0.numberOfLines = 0
    }

    private let subtitleLabel: UILabel = .create {
        $0.textColor = R.color.colorTextSecondary()
        $0.font = .regularFootnote
        $0.numberOfLines = 0
    }

    private let radioSelectorView = RadioSelectorView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    private func setupLayout() {
        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStackView.axis = .vertical
        textStackView.alignment = .leading
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)

        contentView.addSubview(symbolLabel)
        contentView.addSubview(textStackView)
        contentView.addSubview(radioSelectorView)

        symbolLabel.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.width.equalTo(Constants.Symbol.labelSize.width)
            $0.height.equalTo(Constants.Symbol.labelSize.height)
        }

        textStackView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Constants.contentVeritcalOffset)
            $0.leading.equalTo(symbolLabel.snp.trailing).offset(Constants.itemsHorizontalOffset)
            $0.bottom.equalToSuperview().offset(-Constants.contentVeritcalOffset)
        }

        radioSelectorView.snp.makeConstraints {
            $0.leading.equalTo(textStackView.snp.trailing).offset(Constants.itemsHorizontalOffset)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview()
            $0.width.height.equalTo(Constants.radioSelectorSize)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Model

extension CurrencyCollectionViewCell {
    struct Model: Hashable {
        let id: Int
        let title: String
        let subtitle: String
        let symbol: String
        var isSelected: Bool
    }

    func bind(model: Model) {
        symbolLabel.titleLabel.text = model.symbol
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        radioSelectorView.selected = model.isSelected
    }
}

// MARK: - Constants

extension CurrencyCollectionViewCell {
    private enum Constants {
        static let radioSelectorSize: CGFloat = 20
        static let itemsHorizontalOffset: CGFloat = 16
        static let contentVeritcalOffset: CGFloat = 9
        enum Symbol {
            static let contentInsets = UIEdgeInsets(top: 5, left: 0, bottom: 7, right: 0)
            static let cornerRadius: CGFloat = 8
            static let labelSize = CGSize(width: 40, height: 28)
        }
    }
}
