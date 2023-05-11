import UIKit
import SoraUI

protocol StackingRewardDateCellDelegate: AnyObject {
    func datePicker(id: String, selectedDate: Date)
}

final class StackingRewardDateCell: UITableViewCell, Identifiable {
    let datePicker: UIDatePicker = .create {
        if #available(iOS 14, *) {
            $0.preferredDatePickerStyle = .inline
        }
        $0.backgroundColor = R.color.colorSecondaryScreenBackground()
        $0.datePickerMode = .date
        $0.addTarget(self, action: #selector(selectDateAction), for: .valueChanged)
    }

    weak var delegate: StackingRewardDateCellDelegate?
    var id: String = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func selectDateAction() {
        delegate?.datePicker(id: id, selectedDate: datePicker.date)
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
