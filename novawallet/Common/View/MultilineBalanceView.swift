import UIKit

class MultilineBalanceView: UIView {
    let amountLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .largeTitle
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    let priceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularBody
        label.textAlignment = .center
        return label
    }()

    var spacing: CGFloat {
        get {
            stackView.spacing
        }

        set {
            stackView.spacing = newValue
        }
    }

    let stackView: UIStackView = {
        let view = UIStackView()
        view.alignment = .fill
        view.axis = .vertical
        view.spacing = 4.0
        return view
    }()

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
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(amountLabel)
        stackView.addArrangedSubview(priceLabel)
    }

    func bind(viewModel: BalanceViewModelProtocol) {
        amountLabel.text = viewModel.amount

        if let price = viewModel.price {
            priceLabel.isHidden = false
            priceLabel.text = price
        } else {
            priceLabel.text = ""
            priceLabel.isHidden = true
        }
    }
}

final class ShimmerSecureMultibalanceView: GenericPairValueView<
    DotsSecureView<ShimmerLabel>,
    DotsSecureView<ShimmerLabel>
> {
    var amountSecureView: DotsSecureView<ShimmerLabel> { fView }
    var priceSecureView: DotsSecureView<ShimmerLabel> { sView }

    var amountLabel: ShimmerLabel { amountSecureView.originalView }
    var priceLabel: ShimmerLabel { priceSecureView.originalView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    func configure() {
        makeVertical()
        spacing = 2
    }

    func startShimmering() {
        amountLabel.startShimmering()
        priceLabel.startShimmering()
    }

    func stopShimmering() {
        amountLabel.stopShimmering()
        priceLabel.stopShimmering()
    }

    func updateLoadingAnimationIfActive() {
        amountLabel.updateShimmeringIfActive()
        priceLabel.updateShimmeringIfActive()
    }
}

extension ShimmerSecureMultibalanceView {
    func bind(viewModel: SecuredViewModel<LoadableViewModelState<BalanceViewModelProtocol>>) {
        bind(privacyMode: viewModel.privacyMode)

        stopShimmering()

        switch viewModel.originalContent {
        case .loading:
            bind(amount: "", price: nil)
        case let .cached(value):
            bind(amount: value.amount, price: value.price)
            startShimmering()
        case let .loaded(value):
            bind(amount: value.amount, price: value.price)
        }
    }

    func bind(amount: String, price: String?) {
        amountLabel.text = amount

        if let price = price {
            priceLabel.isHidden = false
            priceLabel.text = price
        } else {
            priceLabel.text = ""
            priceLabel.isHidden = true
        }
    }

    func bind(privacyMode: ViewPrivacyMode) {
        amountSecureView.bind(privacyMode)
        priceSecureView.bind(privacyMode)
    }
}
