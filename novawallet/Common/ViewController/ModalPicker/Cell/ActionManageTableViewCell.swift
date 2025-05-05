import Foundation
import UIKit

final class ActionManageTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = ActionManageViewModel

    var checkmarked: Bool {
        get { false }
        set {}
    }

    let manageContentView: StackActionView = {
        let view = StackActionView()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellBackgroundPressed()
        self.selectedBackgroundView = selectedBackgroundView

        backgroundColor = .clear

        setupLayot()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayot() {
        contentView.addSubview(manageContentView)
        manageContentView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }

    func bind(model: Model) {
        let iconColor: UIColor
        let textColor: UIColor

        switch model.style {
        case .available:
            iconColor = R.color.colorIconPrimary()!
            textColor = R.color.colorTextPrimary()!
        case .unavailable:
            iconColor = R.color.colorIconInactive()!
            textColor = R.color.colorButtonTextInactive()!
        case .destructive:
            iconColor = R.color.colorIconNegative()!
            textColor = R.color.colorTextNegative()!
        }

        if model.allowsIconModification {
            manageContentView.iconImageView.image = model.icon?
                .withRenderingMode(.alwaysTemplate)
                .tinted(with: iconColor)
        } else {
            manageContentView.iconImageView.image = model.icon
        }

        manageContentView.titleValueView.valueTop.textColor = textColor

        manageContentView.titleValueView.bind(
            topValue: model.title,
            bottomValue: model.subtitle
        )
    }
}
