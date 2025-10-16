import UIKit
import UIKit_iOS

final class StakingTypeBannerView<ActionView: BindableView>: StakingTypeBaseBannerView {
    let radioSelectorView = RadioSelectorView()
    let titleLabel = UILabel(style: .boldTitle2Primary, numberOfLines: 1)
    let detailsLabel = UILabel(style: .regularSubhedlineSecondary)
    let accountView: ActionView = .create {
        $0.isHidden = true
    }

    let stackView: UIStackView = .create {
        $0.axis = .vertical
        $0.layoutMargins = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        $0.isLayoutMarginsRelativeArrangement = true
        $0.spacing = 16
    }

    var contentInsets: UIEdgeInsets {
        get {
            stackView.layoutMargins
        }
        set {
            stackView.layoutMargins = newValue
            setNeedsLayout()
        }
    }

    func setEnabledStyle(_ isEnabled: Bool) {
        if isEnabled {
            stackView.alpha = 1.0
        } else {
            stackView.alpha = 0.5
        }
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        let descriptionStack = UIView.vStack(alignment: .fill, distribution: .fill, spacing: 16, [
            UIView.hStack(spacing: 12, [
                radioSelectorView,
                titleLabel
            ]),
            UIView.hStack([
                FlexibleSpaceView(),
                detailsLabel
            ])
        ])

        radioSelectorView.snp.makeConstraints {
            $0.width.height.equalTo(24)
        }

        detailsLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel.snp.leading)
        }

        descriptionStack.layoutMargins = .init(top: 0, left: 4, bottom: 0, right: 4)
        descriptionStack.isLayoutMarginsRelativeArrangement = true
        stackView.addArrangedSubview(descriptionStack)
        stackView.setCustomSpacing(20, after: descriptionStack)
        stackView.addArrangedSubview(accountView)
    }

    func setAction(viewModel: ActionView.TModel) {
        accountView.bind(viewModel: viewModel)
    }
}
