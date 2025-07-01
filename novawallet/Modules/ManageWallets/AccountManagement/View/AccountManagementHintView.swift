import UIKit
import UIKit_iOS

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

    lazy var delegateViewContainer = UIView.hStack([
        FlexibleSpaceView(),
        delegateView
    ])

    let delegateView: GenericPairValueView<IconDetailsView, UILabel> = .create {
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
            delegateViewContainer
        ])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
        delegateViewContainer.isHidden = true

        delegateView.snp.makeConstraints { make in
            make.leading.equalTo(iconDetailsView.detailsLabel.snp.leading)
        }
    }

    func bindHint(text: String, icon: UIImage?) {
        iconDetailsView.detailsLabel.text = text
        iconDetailsView.imageView.image = icon
    }

    private var delegateIcon: ImageViewModelProtocol?

    func bindDelegate(viewModel: AccountDelegateViewModel) {
        delegateViewContainer.isHidden = false
        delegateView.fView.detailsLabel.text = viewModel.name
        delegateView.sView.text = viewModel.type
        delegateIcon?.cancel(on: delegateView.fView.imageView)

        viewModel.icon?.loadImage(
            on: delegateView.fView.imageView,
            targetSize: .init(width: 16, height: 16),
            animated: true
        )

        delegateIcon = viewModel.icon
    }
}
