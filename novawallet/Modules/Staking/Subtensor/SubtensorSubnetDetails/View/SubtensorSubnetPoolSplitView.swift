import UIKit

final class SubtensorSubnetPoolSplitView: UIView {
    let taoTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let taoShareLabel: UILabel = .create { $0.apply(style: .semiboldFootnotePrimary) }
    let alphaTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let alphaShareLabel: UILabel = .create { $0.apply(style: .semiboldFootnotePrimary) }
    private let barsView = UIView()
    private let taoBar: UIView = .create { $0.backgroundColor = R.color.colorTextPositive() }
    private let alphaBar: UIView = .create { $0.backgroundColor = R.color.colorButtonBackgroundPrimary() }
    private var split: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let labels = UIView.hStack(spacing: Constants.barGap, [
            taoTitleLabel, taoShareLabel, UIView(), alphaTitleLabel, alphaShareLabel
        ])
        addSubview(labels)
        addSubview(barsView)
        [taoBar, alphaBar].forEach {
            $0.layer.cornerRadius = Constants.barHeight / 2
            barsView.addSubview($0)
        }
        labels.snp.makeConstraints { $0.top.equalToSuperview().inset(12); $0.leading.trailing.equalToSuperview() }
        barsView.snp.makeConstraints {
            $0.top.equalTo(labels.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(Constants.barHeight)
            $0.bottom.equalToSuperview().inset(13)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = barsView.bounds.width
        let taoWidth = max(((width - Constants.barGap) * (split ?? 0)).rounded(), 0)
        let alphaWidth = max(width - Constants.barGap - taoWidth, 0)
        taoBar.frame = CGRect(x: 0, y: 0, width: alphaWidth > 0 ? taoWidth : width, height: Constants.barHeight)
        alphaBar.frame = taoWidth > 0
            ? CGRect(x: taoWidth + Constants.barGap, y: 0, width: alphaWidth, height: Constants.barHeight)
            : CGRect(x: 0, y: 0, width: width, height: Constants.barHeight)
    }

    func bind(_ model: SubtensorSubnetParametersViewModel) {
        split = model.split.map { CGFloat(truncating: $0 as NSDecimalNumber) }
        [
            (taoTitleLabel, model.taoTitle),
            (taoShareLabel, model.taoShare),
            (alphaTitleLabel, model.alphaTitle),
            (alphaShareLabel, model.alphaShare)
        ].forEach { label, text in label.apply(text: text, lineHeight: Constants.lineHeight) }
        barsView.isHidden = split == nil
        setNeedsLayout()
    }
}

private extension SubtensorSubnetPoolSplitView {
    enum Constants {
        static let barHeight: CGFloat = 5
        static let barGap: CGFloat = 6
        static let lineHeight: CGFloat = 18
    }
}
