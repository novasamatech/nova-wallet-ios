import UIKit
import SoraUI

final class NftListItemWithPriceCell: NftListItemCell {
    let priceBackgroundView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.borderType = .top
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorWhite8()!
        return view
    }()

    let tokensLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldFootnote
        label.textColor = R.color.colorWhite()!
        return label
    }()

    let fiatLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTransparentText()!
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    override func bind(viewModel: NftListViewModel) {
        applyPrice(viewModel.price)

        super.bind(viewModel: viewModel)
    }

    private func applyPrice(_ viewModel: BalanceViewModelProtocol?) {
        if let viewModel = viewModel {
            tokensLabel.text = viewModel.amount

            if let fiatPrice = viewModel.price {
                fiatLabel.text = "(\(fiatPrice))"
            } else {
                fiatLabel.text = ""
            }

        } else {
            tokensLabel.text = ""
            fiatLabel.text = ""
        }
    }

    private func setupLayout() {
        contentView.addSubview(priceBackgroundView)
        priceBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8.0)
            make.bottom.equalToSuperview()
            make.height.equalTo(38.0)
        }

        priceBackgroundView.addSubview(tokensLabel)
        tokensLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview().inset(8.0)
        }

        priceBackgroundView.addSubview(fiatLabel)
        fiatLabel.snp.makeConstraints { make in
            make.leading.equalTo(tokensLabel.snp.trailing).offset(6.0)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(8.0)
        }
    }
}
