import UIKit
import SnapKit

@objc
protocol ReceipientKiltViewDelegate {
    func didTapOnAccount(address: AccountAddress)
}

final class ReceipientKiltView: UIView {
    weak var delegate: ReceipientKiltViewDelegate?

    let activityIndicator: UIActivityIndicatorView = .create {
        $0.hidesWhenStopped = true
        $0.style = .medium
        $0.tintColor = R.color.colorIndicatorShimmering()
    }

    let accountSelected: IconDetailsGenericView<IconDetailsView> = .create {
        $0.mode = .detailsIcon
        $0.detailsView.detailsLabel.textColor = R.color.colorIconPositive()
        $0.detailsView.detailsLabel.font = .regularFootnote
        $0.detailsView.detailsLabel.lineBreakMode = .byTruncatingMiddle
        $0.detailsView.spacing = 4
        $0.spacing = 4
    }

    private var model: Model?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapOnView)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(accountSelected)
        addSubview(activityIndicator)

        accountSelected.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
        }
        activityIndicator.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }
    }

    @objc private func didTapOnView() {
        guard let delegate = delegate,
              let model = model,
              let address = model else {
            return
        }

        delegate.didTapOnAccount(address: address)
    }
}

extension ReceipientKiltView {
    typealias Model = AccountAddress?

    func bind(viewModel: LoadableViewModelState<Model>) {
        switch viewModel {
        case .loading:
            accountSelected.isHidden = true
            activityIndicator.startAnimating()
        case let .loaded(value), let .cached(value):
            activityIndicator.stopAnimating()

            if let value = value {
                accountSelected.isHidden = false
                accountSelected.detailsView.detailsLabel.text = value
                accountSelected.detailsView.imageView.image = R.image.iconAlgoItem()
                accountSelected.imageView.image = R.image.iconInfoFilled()?.tinted(with: R.color.colorIconSecondary()!)
            } else {
                accountSelected.detailsView.detailsLabel.text = ""
                accountSelected.detailsView.imageView.image = nil
                accountSelected.imageView.image = nil
            }
        }

        model = viewModel.value
    }
}
