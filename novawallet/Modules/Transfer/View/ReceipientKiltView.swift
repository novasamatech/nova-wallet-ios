import UIKit
import SnapKit

@objc
protocol ReceipientKiltViewDelegate {
    func didTapOnAccountList()
    func didTapOnAccount(address: AccountAddress)
}

final class ReceipientKiltView: UIView {
    var delegate: ReceipientKiltViewDelegate?

    let accountNotFound: IconDetailsView = .create {
        $0.detailsLabel.apply(style: .footnoteSecondary)
        $0.imageView.image = R.image.iconWarningApp()
        $0.spacing = 4
        $0.isHidden = true
    }

    let accountSelected: GenericPairValueView<IconDetailsView, UIImageView> = .create {
        $0.fView.detailsLabel.textColor = R.color.colorIconPositive()
        $0.fView.detailsLabel.font = .regularFootnote
        $0.fView.detailsLabel.lineBreakMode = .byTruncatingMiddle
        $0.fView.imageView.image = R.image.iconAlgoItem()
        $0.fView.spacing = 4
        $0.sView.image = R.image.iconInfoFilled()
        $0.spacing = 4
        $0.isHidden = true
    }

    let accountListControl: YourWalletsControl = .create {
        $0.apply(state: .hidden)
        $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private var currentModel: Model?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(accountNotFound)
        addSubview(accountSelected)
        addSubview(accountListControl)

        accountNotFound.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        accountSelected.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        accountListControl.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    @objc private func didTap() {
        guard let delegate = delegate else {
            return
        }

        switch currentModel {
        case .accountList:
            delegate.didTapOnAccountList()
        case let .accountSelected(address):
            delegate.didTapOnAccount(address: address)
        default:
            break
        }
    }
}

extension ReceipientKiltView {
    enum Model {
        case accountNotFound(String)
        case accountList(String)
        case accountSelected(AccountAddress)
    }

    func bind(viewModel: LoadableViewModelState<Model>?) {
        guard let value = viewModel?.value else {
            accountNotFound.isHidden = true
            accountSelected.isHidden = true
            accountListControl.isHidden = true
            return
        }
        if viewModel?.isLoading == true {
            accountSelected.isHidden = false
            accountNotFound.detailsLabel.text = "Loading"
            return
        }
        switch value {
        case let .accountList(title):
            accountNotFound.isHidden = true
            accountSelected.isHidden = true
            accountListControl.isHidden = false
            accountListControl.bind(model: .init(name: title, image: nil))
        case let .accountSelected(address):
            accountNotFound.isHidden = true
            accountListControl.isHidden = true
            accountSelected.isHidden = false
            accountSelected.fView.detailsLabel.text = address
        case let .accountNotFound(title):
            accountListControl.isHidden = true
            accountSelected.isHidden = true
            accountNotFound.isHidden = false
            accountNotFound.detailsLabel.text = title
        }

        currentModel = value
    }
}
