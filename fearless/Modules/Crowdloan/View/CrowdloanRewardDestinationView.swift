import UIKit

final class CrowdloanRewardDestinationView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let accountView = UIFactory.default.createAccountView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: 12,
            [
                titleLabel,
                accountView
            ]
        )
        accountView.snp.makeConstraints { $0.height.equalTo(52) }

        addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(viewModel: CrowdloanRewardDestinationVM) {
        titleLabel.text = viewModel.title
        accountView.title = viewModel.accountName
        accountView.subtitle = viewModel.accountAddress
        accountView.iconImage = viewModel.substrateIcon
    }
}
