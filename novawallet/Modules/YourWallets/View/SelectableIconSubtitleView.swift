import UIKit

final class SelectableIconSubtitleView: UIView {
    let iconSubtitleView = IconSubtitleView()
    let radioSelectorView = RadioSelectorView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(iconSubtitleView)
        addSubview(radioSelectorView)

        iconSubtitleView.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        radioSelectorView.snp.makeConstraints {
            $0.leading.equalTo(iconSubtitleView.snp.trailing).offset(Constants.horizontalSpace)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview()
            $0.width.equalTo(Constants.radioButtonSize.width)
            $0.height.equalTo(Constants.radioButtonSize.height)
        }
    }
}

// MARK: - Model

extension SelectableIconSubtitleView {
    struct Model {
        let iconSubtitle: IconSubtitleView.Model
        let isSelected: Bool?
    }

    func bind(model: Model) {
        iconSubtitleView.bind(model: model.iconSubtitle)
        guard let isSelected = model.isSelected else {
            radioSelectorView.isHidden = true
            return
        }

        radioSelectorView.isHidden = false
        radioSelectorView.selected = isSelected
    }

    func clear() {
        iconSubtitleView.clear()
    }
}

// MARK: - Constants

extension SelectableIconSubtitleView {
    enum Constants {
        static let horizontalSpace: CGFloat = 25
        static let radioButtonSize = CGSize(width: 20, height: 20)
    }
}
