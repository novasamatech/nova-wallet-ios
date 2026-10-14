import UIKit

final class SubtensorSubnetPoolSplitView: UIView {
    let taoLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let alphaLabel: UILabel = .create { $0.apply(style: .footnoteSecondary); $0.textAlignment = .right }
    private let track: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
        $0.layer.cornerRadius = 3
        $0.clipsToBounds = true
    }

    private let taoBar: UIView = .create { $0.backgroundColor = R.color.colorTextPositive() }
    private let alphaBar: UIView = .create { $0.backgroundColor = R.color.colorButtonBackgroundPrimary() }
    private var split: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let labels = UIView.hStack(spacing: 8, [taoLabel, UIView(), alphaLabel])
        addSubview(labels)
        addSubview(track)
        track.addSubview(taoBar)
        track.addSubview(alphaBar)
        labels.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview() }
        track.snp.makeConstraints {
            $0.top.equalTo(labels.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(6)
            $0.bottom.equalToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = track.bounds.width * (split ?? 0)
        taoBar.frame = CGRect(x: 0, y: 0, width: width, height: track.bounds.height)
        alphaBar.frame = CGRect(x: width, y: 0, width: track.bounds.width - width, height: track.bounds.height)
    }

    func bind(_ model: SubtensorSubnetParametersViewModel) {
        split = model.split.map { CGFloat(truncating: $0 as NSDecimalNumber) }
        taoLabel.text = model.taoShare
        alphaLabel.text = model.alphaShare
        taoBar.isHidden = split == nil
        alphaBar.isHidden = split == nil
        setNeedsLayout()
    }
}
