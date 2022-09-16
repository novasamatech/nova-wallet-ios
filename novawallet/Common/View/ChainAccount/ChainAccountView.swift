import UIKit
import SubstrateSdk

final class ChainAccountView: UIView {
    private enum Constants {
        static let networkIconSize: CGFloat = 32.0
        static let addressIconSize: CGFloat = 16.0
        static let horizontalInsets: CGFloat = 12.0
    }

    let networkIconView: UIImageView = {
        let view = UIImageView()
        return view
    }()

    let networkLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        return label
    }()

    private(set) var accountView: IconDetailsGenericView<UILabel>?

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

        if let accountView = accountView {
            self.viewModel?.displayAddressViewModel?.imageViewModel?.cancel(on: accountView.imageView)
        }

        self.viewModel = viewModel

        networkLabel.text = viewModel.networkName

        if let displayAddressViewModel = viewModel.displayAddressViewModel {
            setupAccountViewIfNeeded()

            guard let accountView = accountView else {
                return
            }

            displayAddressViewModel.imageViewModel?.loadImage(
                on: accountView.imageView,
                targetSize: CGSize(width: Constants.addressIconSize, height: Constants.addressIconSize),
                animated: true
            )

            accountView.detailsView.text = displayAddressViewModel.details
        } else {
            clearAccountView()
        }

        viewModel.networkIconViewModel?.loadImage(
            on: networkIconView,
            targetSize: CGSize(width: Constants.networkIconSize, height: Constants.networkIconSize),
            animated: true
        )

        setNeedsLayout()
    }

    private func setupAccountViewIfNeeded() {
        guard accountView == nil else {
            return
        }

        let view = IconDetailsGenericView<UILabel>()
        view.spacing = 4.0
        view.iconWidth = 16.0
        view.detailsView.textColor = R.color.colorTransparentText()
        view.detailsView.font = .regularFootnote
        view.detailsView.lineBreakMode = .byTruncatingMiddle

        addSubview(view)

        accountView = view

        updateLayout()
    }

    private func clearAccountView() {
        accountView?.removeFromSuperview()
        accountView = nil

        updateLayout()
    }

    private func updateLayout() {
        if let accountView = accountView {
            networkLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview()
                make.leading.equalTo(networkIconView.snp.trailing).offset(Constants.horizontalInsets)
                make.trailing.lessThanOrEqualTo(actionIconView.snp.leading).offset(-Constants.horizontalInsets)
            }

            accountView.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
                make.leading.trailing.equalTo(networkLabel)
            }
        } else {
            networkLabel.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(networkIconView.snp.trailing).offset(Constants.horizontalInsets)
                make.trailing.lessThanOrEqualTo(actionIconView.snp.leading).offset(-Constants.horizontalInsets)
            }
        }
    }

    private func setupLayout() {
        addSubview(networkIconView)
        networkIconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(Constants.networkIconSize)
        }

        addSubview(actionIconView)
        actionIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }

        addSubview(networkLabel)
        networkLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(networkIconView.snp.trailing).offset(Constants.horizontalInsets)
            make.trailing.equalTo(actionIconView.snp.leading).offset(-Constants.horizontalInsets)
        }
    }
}
