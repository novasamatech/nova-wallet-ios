import UIKit

protocol TokensManageRootCellDelegate: AnyObject {
    func rootCellDidSwitch(_ cell: TokensManageRootCell, isOn: Bool)
}

final class TokensManageRootCell: UITableViewCell {
    weak var delegate: TokensManageRootCellDelegate?

    let tokenView = MultichainTokenView()

    let chevronView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrowDown()?.withRenderingMode(.alwaysTemplate)
        view.tintColor = R.color.colorIconSecondary()
        view.contentMode = .scaleAspectFit
    }

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupHandlers()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TokensManageRootViewModel, animated: Bool = false) {
        tokenView.bind(
            title: viewModel.title,
            subtitle: viewModel.subtitle,
            imageViewModel: viewModel.imageViewModel,
            isOn: viewModel.isOn
        )

        tokenView.setIconCornerRadius(iconCornerRadius(for: viewModel.iconShape))

        chevronView.isHidden = !viewModel.isExpandable
        let chevronTransform: CGAffineTransform = viewModel.isExpanded
            ? CGAffineTransform(rotationAngle: .pi)
            : .identity

        if animated {
            UIView.animate(
                withDuration: Constants.expansionAnimationDuration,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseInOut]
            ) {
                self.chevronView.transform = chevronTransform
            }
        } else {
            chevronView.layer.removeAllAnimations()
            chevronView.transform = chevronTransform
        }

        contentView.alpha = viewModel.isPaused ? Constants.pausedAlpha : 1
        switchView.isEnabled = !viewModel.isPaused

        if viewModel.isOn != switchView.isOn {
            switchView.setOn(viewModel.isOn, animated: false)
        }
    }
}

// MARK: Private

private extension TokensManageRootCell {
    func setupHandlers() {
        switchView.addTarget(
            self,
            action: #selector(actionSwitch),
            for: .valueChanged
        )
    }

    func setupLayout() {
        contentView.addSubview(switchView)
        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(chevronView)
        chevronView.snp.makeConstraints { make in
            make.trailing.equalTo(switchView.snp.leading).offset(-Constants.contentSpacing)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.chevronSize)
        }

        contentView.addSubview(tokenView)
        tokenView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(chevronView.snp.leading).offset(-Constants.contentSpacing)
        }
    }

    func iconCornerRadius(for shape: TokensManageRootViewModel.IconShape) -> CGFloat {
        switch shape {
        case .circle:
            return MultichainTokenView.Constants.iconBackgroundSize.height / 2
        case .roundedSquare:
            return Constants.roundedSquareIconRadius
        }
    }

    @objc func actionSwitch() {
        delegate?.rootCellDidSwitch(self, isOn: switchView.isOn)
    }
}

// MARK: Constants

extension TokensManageRootCell {
    enum Constants {
        static let height: CGFloat = 56
        static let horizontalInset: CGFloat = 20
        static let contentSpacing: CGFloat = 12
        static let chevronSize: CGFloat = 24
        static let roundedSquareIconRadius: CGFloat = 12
        static let pausedAlpha: CGFloat = 0.56
        static let expansionAnimationDuration: TimeInterval = 0.25
    }
}
