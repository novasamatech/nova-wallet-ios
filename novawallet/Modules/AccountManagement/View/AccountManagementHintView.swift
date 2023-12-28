import UIKit

final class AccountManagementHintView: UIView {
    let iconDetailsView: IconDetailsView = .create {
        $0.stackView.alignment = .top
        $0.mode = .iconDetails
        $0.iconWidth = 20.0
        $0.spacing = 12.0
        $0.detailsLabel.textColor = R.color.colorTextPrimary()
        $0.detailsLabel.font = .caption1
    }

    let backgroundView: RoundedView = .create {
        $0.apply(style: .chips)
        $0.fillColor = R.color.colorBlockBackground()!
        $0.highlightedFillColor = R.color.colorBlockBackground()!
        $0.cornerRadius = 12.0
    }

    let contentInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

    lazy var proxyViewContainer = UIView.hStack([
        FlexibleSpaceView(),
        proxyView
    ])

    let proxyView: GenericPairValueView<IconDetailsView, UILabel> = .create {
        $0.sView.apply(style: .footnoteSecondary)
        $0.sView.setContentCompressionResistancePriority(.high, for: .horizontal)
        $0.fView.detailsLabel.apply(style: .footnotePrimary)
        $0.fView.iconWidth = 16
        $0.fView.mode = .iconDetails
        $0.makeHorizontal()
        $0.spacing = 4
        $0.fView.spacing = 4
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let contentView = UIView.vStack(spacing: 12, [
            iconDetailsView,
            proxyViewContainer
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
        proxyViewContainer.isHidden = true

        proxyView.snp.makeConstraints { make in
            make.leading.equalTo(iconDetailsView.detailsLabel.snp.leading)
        }
    }

    func bindHint(text: String, icon: UIImage?) {
        iconDetailsView.detailsLabel.text = text
        iconDetailsView.imageView.image = icon
    }

    private var proxyIcon: ImageViewModelProtocol?

    func bindProxy(viewModel: AccountProxyViewModel) {
        proxyViewContainer.isHidden = false
        proxyView.fView.detailsLabel.text = viewModel.name
        proxyView.sView.text = viewModel.type
        proxyIcon?.cancel(on: proxyView.fView.imageView)

        viewModel.icon?.loadImage(
            on: proxyView.fView.imageView,
            targetSize: .init(width: 16, height: 16),
            animated: true
        )

        proxyIcon = viewModel.icon
    }
}
