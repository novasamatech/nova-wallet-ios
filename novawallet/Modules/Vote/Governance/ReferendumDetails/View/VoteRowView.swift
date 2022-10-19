import UIKit
import SwiftUI

final class VoteRowView: UIView {
    lazy var centerView = GenericTitleValueView<UILabel, MultiValueView>(
        titleView: titleLabel,
        valueView: valueView
    )

    private let titleLabel = UILabel(style: .rowTitle, textAlignment: .left)

    private let valueView: MultiValueView = .create {
        $0.apply(style: .rowContrasted)
    }

    private var leadingRectangleView: UIView = .create {
        $0.layer.cornerRadius = 10
    }

    private var trailingImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let contentView = UIView.hStack(
            alignment: .center,
            distribution: .fill,
            spacing: 8,
            [
                leadingRectangleView,
                centerView,
                trailingImageView
            ]
        )
        contentView.setCustomSpacing(16, after: leadingRectangleView)
        addSubview(contentView)
        trailingImageView.snp.makeConstraints {
            $0.height.width.equalTo(16)
        }
        leadingRectangleView.snp.makeConstraints {
            $0.height.equalTo(16)
            $0.width.equalTo(4)
        }
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 44)
    }
}

extension VoteRowView {
    struct Style {
        var color: UIColor
        var accessoryImage: UIImage
    }

    func apply(style: Style) {
        leadingRectangleView.backgroundColor = style.color
        trailingImageView.image = style.accessoryImage
    }
}

extension VoteRowView: BindableView {
    struct Model {
        let title: String
        let votes: String
        let tokens: String
    }

    func bind(viewModel: Model) {
        titleLabel.text = viewModel.title
        valueView.valueTop.text = viewModel.votes
        valueView.valueBottom.text = viewModel.tokens
    }
}

extension MultiValueView {
    struct Style {
        let topLabel: UILabel.Style
        let bottomLabel: UILabel.Style
    }

    func apply(style: Style) {
        valueTop.apply(style: style.topLabel)
        valueBottom.apply(style: style.bottomLabel)
    }
}

extension MultiValueView.Style {
    static let rowContrasted = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorWhite(),
            font: .regularFootnote
        ),
        bottomLabel: .init(
            textColor: R.color.colorWhite64(),
            font: .caption1
        )
    )
    static let accentAmount = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorWhite(),
            font: .boldTitle1
        ),
        bottomLabel: .init(
            textColor: R.color.colorWhite64(),
            font: .regularBody
        )
    )
}

extension UILabel.Style {
    static let rowTitle = UILabel.Style(textColor: R.color.colorWhite(), font: .regularFootnote)
}
