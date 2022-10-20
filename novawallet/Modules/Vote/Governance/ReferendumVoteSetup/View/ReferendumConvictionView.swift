import Foundation
import UIKit
import SoraUI

final class ReferendumConvictionView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.applyCellBackgroundStyle()
        view.cornerRadius = 12.0
    }

    let titleLabel: UILabel = .create { view in
        view.font = .regularFootnote
        view.textColor = R.color.colorTransparentText()
    }

    let slider: DiscreteGradientSlider = .create { view in
        view.applyConvictionDefaultStyle()
    }

    let separatorView: UIView = .create { view in
        view.backgroundColor = R.color.colorWhite8()
    }

    let votesView: UILabel = .create { view in
        view.textColor = R.color.colorWhite()
        view.font = .boldTitle2
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
