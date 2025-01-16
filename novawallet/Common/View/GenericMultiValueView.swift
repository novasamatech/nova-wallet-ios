import UIKit
import UIKit_iOS

class GenericPairValueView<FView: UIView, SView: UIView>: UIView {
    let fView = FView()
    let sView = SView()

    var spacing: CGFloat {
        get {
            stackView.spacing
        }

        set {
            stackView.spacing = newValue
        }
    }

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    func makeVertical() {
        stackView.axis = .vertical

        setNeedsLayout()
    }

    func makeHorizontal() {
        stackView.axis = .horizontal

        setNeedsLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setVerticalAndSpacing(_ spacing: CGFloat) {
        stackView.axis = .vertical
        stackView.spacing = spacing
    }

    func setHorizontalAndSpacing(_ spacing: CGFloat) {
        stackView.axis = .horizontal
        stackView.spacing = spacing
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(fView)
        stackView.addArrangedSubview(sView)
    }
}

class GenericMultiValueView<BottomView: UIView>: UIView {
    let valueTop: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .p1Paragraph
        label.textAlignment = .right
        return label
    }()

    let valueBottom: BottomView

    var spacing: CGFloat {
        get {
            stackView.spacing
        }

        set {
            stackView.spacing = newValue
        }
    }

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        return view
    }()

    init(valueBottom: BottomView = BottomView()) {
        self.valueBottom = valueBottom
        super.init(frame: .zero)

        setupLayout()
    }

    override init(frame: CGRect) {
        valueBottom = .init()
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(valueTop)
        stackView.addArrangedSubview(valueBottom)
    }
}
