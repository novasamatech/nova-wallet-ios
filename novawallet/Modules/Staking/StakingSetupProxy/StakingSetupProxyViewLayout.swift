import UIKit
import SoraFoundation

final class StakingSetupProxyViewLayout: ScrollableContainerLayoutView {
    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let titleLabel: UILabel = .create {
        $0.apply(style: .boldTitle2Primary)
    }

    let authorityLabel: UILabel = .create {
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

    let proxyView: ProxyDepositView = .create {
        $0.imageView.image = R.image.iconLock()!
    }

    let feeView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.verticalOffset = 13
        return view
    }()

    override func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addArrangedSubview(titleLabel, spacingAfter: 16)

        let titleStackView = UIStackView(arrangedSubviews: [
            authorityLabel,
            FlexibleSpaceView(),
            yourWalletsControl
        ])

        addArrangedSubview(titleStackView, spacingAfter: 8)
        addArrangedSubview(accountInputView, spacingAfter: 40)
        addArrangedSubview(proxyView, spacingAfter: 0)
        addArrangedSubview(feeView)
    }
}
