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

    let multiLabelView: MultiValueView = .create { view in
        view.valueTop.apply(style: .regularSubhedlinePrimary)
        view.valueTop.textAlignment = .left

        view.valueBottom.apply(style: .caption1Secondary)
        view.valueBottom.textAlignment = .left
        view.valueBottom.numberOfLines = 0
        view.valueBottom.isHidden

        view.spacing = 4
    }

    var networkLabel: UILabel { multiLabelView.valueTop }
    var secondaryLabel: UILabel { multiLabelView.valueBottom }

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
        view.detailsView.textColor = R.color.colorTextSecondary()
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
            multiLabelView.snp.remakeConstraints { make in
                make.top.equalToSuperview()
                make.leading.equalTo(networkIconView.snp.trailing).offset(Constants.horizontalInsets)
                make.trailing.lessThanOrEqualTo(actionIconView.snp.leading).offset(-Constants.horizontalInsets)
            }

            accountView.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
                make.leading.trailing.equalTo(multiLabelView)
            }
        } else {
            multiLabelView.snp.remakeConstraints { make in
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

        addSubview(multiLabelView)
        multiLabelView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(networkIconView.snp.trailing).offset(Constants.horizontalInsets)
            make.trailing.lessThanOrEqualTo(actionIconView.snp.leading).offset(-Constants.horizontalInsets)
        }
    }
}
