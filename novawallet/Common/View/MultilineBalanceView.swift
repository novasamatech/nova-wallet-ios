import UIKit

class MultilineBalanceView: UIView {
    let amountLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .largeTitle
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    let priceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
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
