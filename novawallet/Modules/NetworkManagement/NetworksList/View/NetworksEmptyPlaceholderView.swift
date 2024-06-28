import UIKit

class NetworksEmptyTableViewCell: PlainBaseTableViewCell<NetworksEmptyPlaceholderView> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }
}

protocol NetworksEmptyPlaceholderViewDelegate: AnyObject {
    func didTapAddNetwork()
}

final class NetworksEmptyPlaceholderView: UIView {
    weak var delegate: NetworksEmptyPlaceholderViewDelegate?

    let imageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.imageEmptyNetworksPlaceholder()
    }

    let messageLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlineSecondary)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    let button: UIButton = .create { view in
        view.addTarget(
            self,
            action: #selector(actionButtonTap),
            for: .touchUpInside
        )
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

    func bind(with viewModel: NetworksListViewLayout.Placeholder) {
        messageLabel.text = viewModel.message
        button.titleLabel?.apply(style: .semiboldSubheadlineAccent)
        button.setTitleColor(R.color.colorButtonTextAccent(), for: .normal)
        button.setTitle(viewModel.buttonTitle, for: .normal)
    }
}

// MARK: Private

private extension NetworksEmptyPlaceholderView {
    func setupLayout() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(218)
            make.height.equalTo(89)
            make.top.equalToSuperview().offset(95)
        }

        addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(15)
            make.leading.trailing.equalTo(imageView)
        }

        addSubview(button)
        button.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(10)
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
        }
    }

    @objc func actionButtonTap() {
        delegate?.didTapAddNetwork()
    }
}
