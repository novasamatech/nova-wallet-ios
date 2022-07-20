import UIKit
import SoraFoundation

final class CreateWatchOnlyViewLayout: UIView {
    static func createSectionTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        return label
    }

    static func createHintLabel() -> UILabel {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorWhite48()
        label.numberOfLines = 0
        return label
    }

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .boldTitle2
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.numberOfLines = 0
        return label
    }()

    let presetsTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let presetsContainerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .horizontal)
        view.stackView.distribution = .fill
        view.stackView.alignment = .center
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = 6.0
        view.scrollView.showsHorizontalScrollIndicator = false
        return view
    }()

    let walletNameTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let walletNameInputView = TextInputView()

    let walletNameHintLabel = CreateWatchOnlyViewLayout.createHintLabel()

    let substrateAddressTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let substrateAddressInputView: AccountInputView = {
        let view = AccountInputView()
        view.showsMyself = false

        view.localizablePlaceholder = LocalizableResource { locale in
            R.string.localizable.commonSubstrateAddressTitle(preferredLanguages: locale.rLanguages)
        }

        return view
    }()

    let substrateAddressHintLabel = CreateWatchOnlyViewLayout.createHintLabel()

    let evmAddressTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let evmAddressInputView: AccountInputView = {
        let view = AccountInputView()
        view.showsMyself = false

        view.localizablePlaceholder = LocalizableResource { locale in
            R.string.localizable.commonEvmAddress(preferredLanguages: locale.rLanguages)
        }

        return view
    }()

    let evmAddressHintLabel = CreateWatchOnlyViewLayout.createHintLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(detailsLabel)
        containerView.stackView.setCustomSpacing(16.0, after: detailsLabel)

        containerView.stackView.addArrangedSubview(presetsTitleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: presetsTitleLabel)

        containerView.stackView.addArrangedSubview(presetsContainerView)
        containerView.stackView.setCustomSpacing(16.0, after: presetsContainerView)

        containerView.stackView.addArrangedSubview(walletNameTitleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: walletNameTitleLabel)

        containerView.stackView.addArrangedSubview(walletNameInputView)
        containerView.stackView.setCustomSpacing(8.0, after: walletNameInputView)

        containerView.stackView.addArrangedSubview(walletNameHintLabel)
        containerView.stackView.setCustomSpacing(20.0, after: walletNameHintLabel)

        containerView.stackView.addArrangedSubview(substrateAddressTitleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: substrateAddressTitleLabel)

        containerView.stackView.addArrangedSubview(substrateAddressInputView)
        containerView.stackView.setCustomSpacing(8.0, after: substrateAddressInputView)

        containerView.stackView.addArrangedSubview(substrateAddressHintLabel)
        containerView.stackView.setCustomSpacing(20.0, after: substrateAddressHintLabel)

        containerView.stackView.addArrangedSubview(evmAddressTitleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: evmAddressTitleLabel)

        containerView.stackView.addArrangedSubview(evmAddressInputView)
        containerView.stackView.setCustomSpacing(8.0, after: evmAddressInputView)

        containerView.stackView.addArrangedSubview(evmAddressHintLabel)
        containerView.stackView.setCustomSpacing(20.0, after: evmAddressHintLabel)
    }
}
