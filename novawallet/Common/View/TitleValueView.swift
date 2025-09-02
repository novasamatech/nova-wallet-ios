import UIKit
import UIKit_iOS

final class TitleValueView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.backgroundColor = .clear
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDivider()!
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        addSubview(valueLabel)
        valueLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }
    }
}
