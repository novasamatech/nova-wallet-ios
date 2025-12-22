import UIKit
import Foundation_iOS

final class ChangeWatchOnlyViewLayout: UIView {
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

    let addressTitleLabel = CreateWatchOnlyViewLayout.createSectionTitleLabel()

    let addressInputView: AccountInputView = {
        let view = AccountInputView()
        view.showsMyself = false

        view.localizablePlaceholder = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonAddress()
        }

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

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
        containerView.stackView.setCustomSpacing(24.0, after: detailsLabel)

        containerView.stackView.addArrangedSubview(addressTitleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: addressTitleLabel)

        containerView.stackView.addArrangedSubview(addressInputView)
    }
}
