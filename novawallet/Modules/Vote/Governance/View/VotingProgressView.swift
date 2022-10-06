import UIKit

final class VotingProgressView: UIView {
    let thresholdView: IconDetailsView = .create {
        $0.detailsLabel.apply(style: .referendaTimeView)
    }

    let slider: SegmentedSliderView = .create {
        $0.apply(style: .governance)
    }

    let ayeProgressLabel: UILabel = .init(style: .referendaTimeView, textAlignment: .left)
    let passProgressLabel: UILabel = .init(style: .referendaTimeView, textAlignment: .center)
    let nayProgressLabel: UILabel = .init(style: .referendaTimeView, textAlignment: .right)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let progressStack = UIStackView(arrangedSubviews: [
            ayeProgressLabel,
            passProgressLabel,
            nayProgressLabel
        ])
        progressStack.distribution = .fillEqually

        let mainStack = UIStackView(arrangedSubviews: [
            thresholdView,
            slider,
            progressStack
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 6

        addSubview(mainStack)
        mainStack.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension UILabel {
    struct Style {
        let textColor: UIColor?
        let font: UIFont
    }

    convenience init(style: Style, textAlignment: NSTextAlignment = .left) {
        self.init()
        self.textAlignment = textAlignment
        apply(style: style)
    }

    func apply(style: Style) {
        textColor = style.textColor
        font = style.font
    }
}

extension UILabel.Style {
    static let referendaTimeView = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
}
