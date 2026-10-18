import UIKit
import UIKit_iOS

final class SubtensorFactChipsView: UIView {
    let stackView = UIView.hStack(alignment: .center, distribution: .fill, spacing: Constants.spacing, [])

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(titles: [String]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        titles.forEach { title in
            stackView.addArrangedSubview(createChip(title: title))
        }

        isHidden = titles.isEmpty
    }
}

private extension SubtensorFactChipsView {
    enum Constants {
        static let spacing: CGFloat = 6
        static let height: CGFloat = 24
        static let cornerRadius: CGFloat = 6
        static let insets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
    }

    func createChip(title: String) -> BorderedLabelView {
        let chip = BorderedLabelView()
        chip.titleLabel.apply(style: .footnotePrimary)
        chip.titleLabel.text = title
        chip.backgroundView.cornerRadius = Constants.cornerRadius
        chip.contentInsets = Constants.insets

        chip.snp.makeConstraints { make in
            make.height.equalTo(Constants.height)
        }

        return chip
    }
}
