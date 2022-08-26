import UIKit

final class SelectableIconSubtitleCollectionViewCell: UICollectionViewCell {
    let view = SelectableIconSubtitleView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(9)
            $0.leading.trailing.equalToSuperview()
        }
    }
    
    override func prepareForReuse() {
        view.clear()
    }
}

// MARK: - Model

extension SelectableIconSubtitleCollectionViewCell {
    typealias Model = SelectableIconSubtitleView.Model

    func bind(model: Model) {
        view.bind(model: model)
    }
}
