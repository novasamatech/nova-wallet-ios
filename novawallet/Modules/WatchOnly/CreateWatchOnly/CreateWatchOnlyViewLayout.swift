import UIKit
import Foundation_iOS
import UIKit_iOS

final class CreateWatchOnlyViewLayout: UIView {
    enum Constants {
        static let presetsInsets: CGFloat = 16.0
    }

    static func createSectionTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }

    static func createHintLabel() -> UILabel {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 0.0, right: 16.0)
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
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldTitle3
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        label.numberOfLines = 0
        return label
    }()

    let presetsTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let presetsContainerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .horizontal)
        view.stackView.distribution = .fill
        view.stackView.alignment = .center
        view.stackView.layoutMargins = UIEdgeInsets(
            top: 0.0,
            left: Constants.presetsInsets,
            bottom: 0.0,
            right: Constants.presetsInsets
        )

        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = 6.0
        view.scrollView.showsHorizontalScrollIndicator = false
        view.clipsToBounds = false
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
            R.string(preferredLanguages: locale.rLanguages).localizable.commonSubstrateAddressTitle()
        }

        return view
    }()

    let substrateAddressHintLabel = CreateWatchOnlyViewLayout.createHintLabel()

    let evmAddressTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let evmAddressInputView: AccountInputView = {
        let view = AccountInputView()
        view.showsMyself = false

        view.localizablePlaceholder = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonEvmAddress()
        }

        return view
    }()

    let evmAddressHintLabel = CreateWatchOnlyViewLayout.createHintLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addPresetButton(with title: String) -> RoundedButton {
        let button = RoundedButton()
        button.imageWithTitleView?.titleFont = .regularFootnote
        button.roundedBackgroundView?.shadowOpacity = 0.0
        button.roundedBackgroundView?.strokeWidth = 0.0
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.cornerRadius = 10.0
        button.changesContentOpacityWhenHighlighted = true
        button.contentInsets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0)
        button.imageWithTitleView?.title = title

        presetsContainerView.stackView.addArrangedSubview(button)

        button.snp.makeConstraints { make in
            make.height.equalTo(32.0)
        }

        return button
    }

    func clearPresets() {
        let presetButtons = presetsContainerView.stackView.arrangedSubviews

        presetButtons.forEach { $0.removeFromSuperview() }
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

        let presetsContentView = UIView()
        containerView.stackView.addArrangedSubview(presetsContentView)

        presetsContentView.addSubview(presetsContainerView)
        presetsContainerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(-Constants.presetsInsets)
        }

        containerView.stackView.setCustomSpacing(16.0, after: presetsContentView)

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
