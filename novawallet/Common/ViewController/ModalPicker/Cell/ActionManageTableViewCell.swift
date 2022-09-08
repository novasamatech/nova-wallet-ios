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
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedAccent()
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
        manageContentView.iconImageView.image = model.icon
        manageContentView.titleLabel.text = model.title
    }
}
