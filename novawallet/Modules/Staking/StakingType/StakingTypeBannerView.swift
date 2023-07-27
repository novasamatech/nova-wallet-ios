import SoraUI

final class StakingTypeBannerView: StakingTypeBaseBannerView {
    let radioSelectorView = RadioSelectorView()
    let titleLabel = UILabel(style: .boldTitle2Primary, numberOfLines: 1)
    let detailsLabel = UILabel(style: .regularSubhedlineSecondary)
    private(set) var accountView: StakingTypeAccountView?

    let stackView: UIStackView = .create {
        $0.axis = .vertical
        $0.alignment = .leading
        $0.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 0)
        $0.isLayoutMarginsRelativeArrangement = true
        $0.spacing = 8
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

        let hStack = UIView.hStack([
            radioSelectorView,
            titleLabel
        ])

        radioSelectorView.snp.makeConstraints {
            $0.width.height.equalTo(24)
        }

        stackView.addArrangedSubview(hStack)
        stackView.addArrangedSubview(detailsLabel)
        clipsToBounds = true
    }

    func setAction(viewModel: StakingTypeAccountViewModel?) {
        if let viewModel = viewModel {
            if accountView == nil {
                let view = StakingTypeAccountView(frame: .zero)
                stackView.addSubview(view)
                accountView = view
            }
            accountView?.bind(viewModel: viewModel)
        } else {
            accountView?.removeFromSuperview()
            accountView = nil
        }
    }
}
