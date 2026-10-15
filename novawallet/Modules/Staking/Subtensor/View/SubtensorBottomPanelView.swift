import UIKit

final class SubtensorBottomPanelView: UIView {
    let backgroundView: TriangularedView = .create { view in
        view.shadowOpacity = 0
        view.sideLength = Constants.cornerRadius
        view.cornerCut = [.topLeft, .topRight]
        view.fillColor = R.color.colorBlockBackground()!
        view.strokeColor = R.color.colorContainerBorder()!
        view.strokeWidth = Constants.borderWidth
    }

    let contentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension SubtensorBottomPanelView {
    enum Constants {
        static let cornerRadius: CGFloat = 16
        static let borderWidth: CGFloat = 1
        static let strokeOutset = borderWidth / 2
        static let contentInset: CGFloat = 16
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.strokeOutset)
            make.leading.trailing.bottom.equalToSuperview().inset(-Constants.strokeOutset)
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(Constants.contentInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.contentInset)
        }
    }
}
