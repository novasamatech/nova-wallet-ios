import UIKit
import Foundation_iOS

final class StakingSetupProxyViewLayout: ScrollableContainerLayoutView {
    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let titleLabel: UILabel = .create {
        $0.apply(style: .boldTitle3Primary)
    }

    let proxyTitleLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
    }

    let yourWalletsControl: YourWalletsControl = .create {
        $0.apply(state: .hidden)
        $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    let accountInputView: AccountInputView = .create {
        $0.localizablePlaceholder = LocalizableResource { locale in
            R.string.localizable.transferSetupRecipientInputPlaceholder(preferredLanguages: locale.rLanguages)
        }
    }

    let proxyDepositView: ProxyDepositView = .create {
        $0.imageView.image = R.image.iconLock()!.withTintColor(R.color.colorIconSecondary()!)
        $0.contentInsets = .zero
    }

    let feeView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.verticalOffset = 13
        return view
    }()

    let web3NameReceipientView = Web3NameReceipientView()

    override func setupLayout() {
        super.setupLayout()

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addArrangedSubview(titleLabel, spacingAfter: 8)

        let titleStackView = UIStackView(arrangedSubviews: [
            proxyTitleLabel,
            FlexibleSpaceView(),
            yourWalletsControl
        ])

        addArrangedSubview(titleStackView, spacingAfter: 0)
        addArrangedSubview(accountInputView, spacingAfter: 8)
        addArrangedSubview(web3NameReceipientView, spacingAfter: 16)
        addArrangedSubview(proxyDepositView, spacingAfter: 0)
        addArrangedSubview(feeView)
    }
}
