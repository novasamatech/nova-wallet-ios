import UIKit

class CollectionViewContainerCell<ContentView: UIView>: UICollectionViewCell {
    let view = ContentView()

    var separatorView: UIView?

    open var changesContentOpacityWhenHighlighted: Bool = false {
        didSet {
            if !changesContentOpacityWhenHighlighted {
                view.alpha = 1.0
            }
        }
    }

    override var isHighlighted: Bool {
        didSet {
            if changesContentOpacityWhenHighlighted {
                view.alpha = isHighlighted ? 0.5 : 1.0
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        separatorView?.removeFromSuperview()
        separatorView = nil
    }

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
            $0.edges.equalToSuperview()
        }
    }

    func addSeparatorLine(
        _ height: CGFloat = 1,
        color: UIColor = R.color.colorDivider()!,
        horizontalSpace: CGFloat = UIConstants.horizontalInset
    ) {
        separatorView = addBottomSeparator(
            height,
            color: color,
            horizontalSpace: horizontalSpace
        )
    }
}
