import UIKit
import SoraUI

final class StackingRewardDateCell: UITableViewCell {
    let datePicker: UIDatePicker = .create {
        if #available(iOS 13.4, *) {
            $0.preferredDatePickerStyle = .compact
        }
        $0.datePickerMode = .date
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(datePicker)
        datePicker.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(date: Date?) {
        date.map {
            datePicker.date = $0
        }
    }
}
