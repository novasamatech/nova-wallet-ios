import SoraUI

final class StakingTypeBannerView<ActionView: BindableView>: StakingTypeBaseBannerView {
    let radioSelectorView = RadioSelectorView()
    let titleLabel = UILabel(style: .boldTitle2Primary, numberOfLines: 1)
    let detailsLabel = UILabel(style: .regularSubhedlineSecondary)
    private(set) var accountView: ActionView?

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
        clipsToBounds = true
    }

    func setAction(viewModel: ActionView.TModel?) {
        if let viewModel = viewModel {
            if accountView == nil {
                let view = ActionView(frame: .zero)
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
