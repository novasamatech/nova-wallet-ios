import UIKit

class GenericTitleValueView<T: UIView, V: UIView>: UIView {
    enum Alignment {
        case natural
        case left
    }

    let titleView: T
    let valueView: V

    convenience init() {
        let defaultSize = CGRect(origin: .zero, size: CGSize(width: 340, height: 20))
        self.init(frame: defaultSize)
    }

    init(titleView: T = T(), valueView: V = V()) {
        self.titleView = titleView
        self.valueView = valueView

        super.init(frame: .zero)

        setup()
    }

    override init(frame: CGRect) {
        titleView = T()
        valueView = V()

        super.init(frame: frame)

        setup()
    }

    var spacing: CGFloat = 8.0 {
        didSet {
            remakeConstraints()
        }
    }

    var alignment: Alignment = .natural {
        didSet {
            remakeConstraints()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let height = max(titleView.intrinsicContentSize.height, valueView.intrinsicContentSize.height)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    private func setup() {
        addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        addSubview(valueView)
        valueView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleView.snp.trailing).offset(spacing)
        }
    }

    private func remakeConstraints() {
        switch alignment {
        case .natural:
            valueView.snp.remakeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.leading.greaterThanOrEqualTo(titleView.snp.trailing).offset(spacing)
            }

            setNeedsLayout()
        case .left:
            valueView.snp.remakeConstraints { make in
                make.leading.equalTo(titleView.snp.trailing).offset(spacing)
                make.centerY.equalToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
            }

            setNeedsLayout()
        }
    }
}
