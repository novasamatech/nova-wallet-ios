import UIKit

final class AboutCrowdloansView: UIView {
    let aboutLabel: UILabel = .create {
        $0.font = .p1Paragraph
        $0.textColor = R.color.colorWhite()!
    }

    let descriptionLabel: UILabel = .create {
        $0.font = .p2Paragraph
        $0.textColor = R.color.colorTransparentText()
        $0.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(aboutLabel)
        aboutLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(16.0)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(aboutLabel.snp.bottom).offset(12.0)
        }
    }

    func bind(model: AboutCrowdloansViewModel) {
        aboutLabel.text = model.title
        descriptionLabel.text = model.subtitle
    }
}

struct AboutCrowdloansViewModel {
    let title: String
    let subtitle: String
}
