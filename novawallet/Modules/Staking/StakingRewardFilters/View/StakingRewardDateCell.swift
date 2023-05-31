import UIKit
import SoraUI

protocol StakingRewardDateCellDelegate: AnyObject {
    func datePicker(id: String, selectedDate: Date)
}

final class StakingRewardDateCell: UITableViewCell, Identifiable {
    let datePicker: UIDatePicker = .create {
        if #available(iOS 14, *) {
            $0.preferredDatePickerStyle = .inline
        }
        $0.backgroundColor = R.color.colorSecondaryScreenBackground()
        $0.datePickerMode = .date
    }

    weak var delegate: StakingRewardDateCellDelegate?
    var id: String = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
        datePicker.addTarget(self, action: #selector(selectDateAction), for: .valueChanged)
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

    func bind(date: Date?, minDate: Date?, maxDate: Date?) {
        date.map {
            datePicker.date = $0
        }
        datePicker.minimumDate = minDate
        datePicker.maximumDate = maxDate
    }
}
