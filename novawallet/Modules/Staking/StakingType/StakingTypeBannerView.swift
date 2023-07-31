import SoraUI

final class StakingTypeBannerView: StakingTypeBaseBannerView {
    let radioSelectorView = RadioSelectorView()
    let titleLabel = UILabel(style: .boldTitle2Primary, numberOfLines: 1)
    let detailsLabel = UILabel(style: .regularSubhedlineSecondary)
    private(set) var accountView: StakingTypeAccountView?

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

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        let descriptionStack = UIView.vStack(alignment: .fill, distribution: .fill, spacing: 16, [
            UIView.hStack(spacing: 12, [
                radioSelectorView,
                titleLabel
            ]),
            detailsLabel
        ])

//        titleLabel.setContentHuggingPriority(.low, for: .horizontal)
//        detailsLabel.setContentHuggingPriority(.low, for: .horizontal)

        radioSelectorView.snp.makeConstraints {
            $0.width.height.equalTo(24)
        }

        descriptionStack.layoutMargins = .init(top: 0, left: 4, bottom: 0, right: 4)
        descriptionStack.isLayoutMarginsRelativeArrangement = true
        stackView.addArrangedSubview(descriptionStack)
        clipsToBounds = true
    }

    func setAction(viewModel: StakingTypeAccountViewModel?) {
        if let viewModel = viewModel {
            if accountView == nil {
                let view = StakingTypeAccountView(frame: .zero)
                stackView.addArrangedSubview(view)
                view.snp.makeConstraints {
                    $0.height.equalTo(48)
                }
                accountView = view
            }
            accountView?.bind(viewModel: viewModel)
        } else {
            accountView?.removeFromSuperview()
            accountView = nil
        }
    }
}
