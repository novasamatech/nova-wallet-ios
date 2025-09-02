import UIKit
import UIKit_iOS

protocol StakingRewardDateCellDelegate: AnyObject {
    func datePicker(id: String, selectedDate: Date)
}

final class StakingRewardDateCell: UITableViewCell, Identifiable {
    let datePicker: UIDatePicker = .create {
        $0.preferredDatePickerStyle = .inline
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

    override func prepareForReuse() {
        datePicker.minimumDate = nil
        datePicker.maximumDate = nil
        super.prepareForReuse()
    }

    func bind(date: Date?, minDate: Date?, maxDate: Date?) {
        if let date = date {
            if let minDate = minDate, date < minDate {
                return
            }
            if let maxDate = maxDate, date > maxDate {
                return
            }
            datePicker.date = date
        }

        datePicker.minimumDate = minDate
        datePicker.maximumDate = maxDate
    }
}
