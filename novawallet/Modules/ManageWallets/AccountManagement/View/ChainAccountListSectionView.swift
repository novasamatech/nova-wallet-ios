import UIKit
import UIKit_iOS
import Foundation_iOS

class ChainAccountListSectionView: UITableViewHeaderFooterView {
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldCaps2
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(8.0)
        }
    }

    func bind(description: String) {
        descriptionLabel.text = description.uppercased()
    }
}

final class ChainAccountListSectionWithActionView: ChainAccountListSectionView {
    let actionButton: RoundedButton = .create { button in
        button.applyAccessoryCaps2Style()
    }

    private var prevAction: UIAction?

    override func setupLayout() {
        contentView.addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview()
            make.height.equalTo(29)
        }

        contentView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.trailing.lessThanOrEqualTo(actionButton.snp.leading)
            make.centerY.equalTo(actionButton)
        }
    }

    func bind(title: String, action: IconWithTitleViewModel, handler: @escaping () -> Void) {
        descriptionLabel.text = title.uppercased()

        actionButton.bindIconWithTitle(
            viewModel: IconWithTitleViewModel(
                icon: action.icon?.tinted(with: R.color.colorButtonTextAccent()!),
                title: action.title.uppercased()
            )
        )

        if let prevAction {
            actionButton.removeAction(prevAction, for: .touchUpInside)
        }

        let action = UIAction { _ in
            handler()
        }

        prevAction = action
        actionButton.addAction(action, for: .touchUpInside)
    }
}
