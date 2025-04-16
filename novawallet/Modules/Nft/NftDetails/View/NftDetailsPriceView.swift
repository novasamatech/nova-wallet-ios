import UIKit
import UIKit_iOS

final class NftDetailsPriceView: RoundedView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .regularSubheadline
        return label
    }()

    let tokenLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldTitle3
        return label
    }()

    let priceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularSubheadline
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: BalanceViewModelProtocol) {
        tokenLabel.text = viewModel.amount

        if let price = viewModel.price {
            priceLabel.text = "(\(price))"
        } else {
            priceLabel.text = ""
        }
    }

    private func configureStyle() {
        applyFilledBackgroundStyle()

        cornerRadius = 12.0
        fillColor = R.color.colorBottomSheetBackground()!
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(16.0)
        }

        addSubview(tokenLabel)
        tokenLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(8.0)
            make.bottom.equalToSuperview().inset(20.0)
        }

        addSubview(priceLabel)
        priceLabel.snp.makeConstraints { make in
            make.leading.equalTo(tokenLabel.snp.trailing).offset(8.0)
            make.centerY.equalTo(tokenLabel.snp.centerY)
            make.trailing.equalToSuperview().inset(16.0)
        }

        tokenLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }
}
