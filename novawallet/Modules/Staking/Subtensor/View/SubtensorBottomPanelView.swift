import UIKit

final class SubtensorBottomPanelView: UIView {
    enum Style {
        case translucent
        case solid
    }

    let backgroundView: UIView = .create { view in
        view.layer.cornerRadius = Constants.cornerRadius
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    let contentView = UIView()

    init(style: Style = .translucent) {
        super.init(frame: .zero)

        apply(style: style)
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
        static let contentInset: CGFloat = 16
    }

    func apply(style: Style) {
        switch style {
        case .translucent:
            backgroundView.backgroundColor = R.color.colorBlockBackground()
            backgroundView.layer.borderWidth = Constants.borderWidth
            backgroundView.layer.borderColor = R.color.colorContainerBorder()!.cgColor
        case .solid:
            backgroundView.backgroundColor = R.color.colorBottomSheetBackground()
        }
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.bottom.equalToSuperview().inset(-Constants.borderWidth)
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(Constants.contentInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.contentInset)
        }
    }
}
