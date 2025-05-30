import UIKit
import UIKit_iOS

class CommonInputView: UIView {
    let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorBlockBackground()!
        view.highlightedStrokeColor = R.color.colorBlockBackground()!
        view.strokeWidth = 1.0
        return view
    }()

    let animatedInputField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.placeholderFont = .p1Paragraph
        field.placeholderColor = R.color.colorHintText()!
        field.textColor = R.color.colorTextPrimary()!
        field.textFont = .p1Paragraph
        field.cursorColor = R.color.colorTextPrimary()!
        return field
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
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(52.0)
        }

        addSubview(animatedInputField)
        animatedInputField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(4.0)
        }
    }
}
