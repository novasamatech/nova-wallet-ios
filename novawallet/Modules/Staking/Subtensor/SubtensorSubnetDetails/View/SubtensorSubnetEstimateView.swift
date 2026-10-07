import UIKit
import UIKit_iOS

final class SubtensorSubnetEstimateView: UIView {
    let chipButtons: [TriangularedButton] = (0 ..< 4).map { index in
        let button = TriangularedButton()
        button.tag = index
        button.imageWithTitleView?.titleFont = .semiBoldFootnote
        button.applySecondaryEnabledStyle()
        return button
    }

    let holdLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
        label.numberOfLines = 0
    }

    let noteLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorSubnetEstimateViewModel) {
        zip(chipButtons, viewModel.chips).enumerated().forEach { index, pair in
            let (button, title) = pair
            let isMax = index == viewModel.chips.count - 1
            let isEnabled = !isMax || viewModel.isMaxEnabled

            if !isEnabled {
                button.applyDisabledStyle()
            } else if index == viewModel.selectedChipIndex {
                button.applyEnabledStyle()
            } else {
                button.applySecondaryEnabledStyle()
            }

            button.isEnabled = isEnabled
            button.imageWithTitleView?.title = title
            button.invalidateLayout()
        }

        holdLabel.text = viewModel.hold
        holdLabel.isHidden = viewModel.hold == nil
    }
}

private extension SubtensorSubnetEstimateView {
    func setupLayout() {
        let chipsView = UIView.hStack(distribution: .fillEqually, spacing: 8, chipButtons)

        chipsView.snp.makeConstraints { make in
            make.height.equalTo(36)
        }

        let contentView = UIView.vStack(spacing: 8, [chipsView, holdLabel, noteLabel])
        contentView.setCustomSpacing(16, after: chipsView)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16))
        }
    }
}
