import UIKit
import SubstrateSdk

final class ChainAccountView: UIView {
    let networkIconView: UIImageView = {
        let view = UIImageView()
        return view
    }()

    let networkLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let accountIconView = PolkadotIconView()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    let actionIconView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconMore()
        return view
    }()

    private var viewModel: ChainAccountViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ChainAccountViewModel) {
        self.viewModel?.networkIconViewModel?.cancel(on: networkIconView)
        self.viewModel = viewModel

        networkLabel.text = viewModel.networkName
        addressLabel.text = viewModel.address
        accountIconView.bind(icon: viewModel.accountIcon)

        viewModel.networkIconViewModel?.loadImage(
            on: networkIconView,
            targetSize: CGSize(width: 44, height: 44),
            animated: true
        )
    }

    private func setupLayout() {
        addSubview(networkIconView)
        networkIconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(32.0)
        }

        addSubview(actionIconView)
        actionIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }

        addSubview(networkLabel)
        networkLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(0.0)
            make.leading.equalTo(networkIconView.snp.trailing).offset(12.0)
            make.trailing.equalTo(actionIconView.snp.leading).offset(-16.0)
        }

        addSubview(accountIconView)
        accountIconView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.leading.equalTo(networkIconView.snp.trailing).offset(12.0)
            make.size.equalTo(16.0)
        }

        addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.leading.equalTo(accountIconView.snp.trailing).offset(4.0)
            make.centerY.equalTo(accountIconView)
            make.trailing.equalTo(actionIconView.snp.leading).offset(-16.0)
        }
    }
}
