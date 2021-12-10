import UIKit
import SoraUI

final class TitleMultiValueView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let valueTop: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    var valueBottom: UILabel {
        if let label = privateValueBottom {
            return label
        } else {
            return setupBottomLabel()
        }
    }

    private var privateValueBottom: UILabel?

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.backgroundColor = .clear
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDarkGray()!
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

    func resetToSingleValue() {
        privateValueBottom?.removeFromSuperview()
        privateValueBottom = nil

        valueTop.snp.remakeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(self.snp.centerY)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }
    }

    private func setupBottomLabel() -> UILabel {
        let label = UILabel()
        label.textColor = R.color.colorGray()
        label.font = .p2Paragraph

        privateValueBottom = label

        valueTop.snp.remakeConstraints { make in
            make.trailing.equalToSuperview()
            make.bottom.equalTo(self.snp.centerY)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        addSubview(label)
        label.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalTo(self.snp.centerY)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        return label
    }

    private func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(valueTop)
        valueTop.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(self.snp.centerY)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }
    }
}
