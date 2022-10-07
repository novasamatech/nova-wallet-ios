import UIKit

final class YourVoteView: UIView {
    let topLine = createSeparator(color: R.color.colorWhite8())

    let typeLabel: BorderedLabelView = .create {
        $0.titleLabel.apply(style: .type)
        $0.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
    }

    let ayeVoteLabel = UILabel(style: .votes, textAlignment: .left)
    let nayVoteLabel = UILabel(style: .votes, textAlignment: .left)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: 12,
            [
                topLine,
                UIView.hStack(
                    spacing: 6,
                    [
                        typeLabel,
                        ayeVoteLabel
                    ]
                ),
                UIView.hStack(
                    spacing: 6,
                    [
                        typeLabel,
                        nayVoteLabel
                    ]
                )
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension UILabel.Style {
    static let type = UILabel.Style(
        textColor: R.color.colorDarkGreen(),
        font: .semiBoldCaps1
    )
    static let votes = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
}
