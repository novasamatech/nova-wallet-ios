import Foundation
import UIKit
import UIKit_iOS

final class ReferendumConvictionView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.apply(style: .roundedLightCell)
    }

    let titleLabel = UILabel(style: .footnoteSecondary)

    let slider: DiscreteGradientSlider = .create { view in
        view.applyConvictionDefaultStyle()
    }

    let separatorView: UIView = .create { view in
        view.backgroundColor = R.color.colorDivider()
    }

    let votesView: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle3
        view.textAlignment = .center
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(votes: String) {
        votesView.text = votes

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(backgroundView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let stackView = UIView.vStack([
            titleLabel,
            slider,
            separatorView,
            votesView
        ])

        stackView.spacing = 0
        stackView.setCustomSpacing(13.0, after: titleLabel)
        stackView.setCustomSpacing(14.0, after: slider)
        stackView.setCustomSpacing(12.0, after: separatorView)

        backgroundView.addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16.0)
        }

        separatorView.snp.makeConstraints { make in
            make.height.equalTo(1)
        }
    }
}
