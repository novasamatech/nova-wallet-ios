import UIKit
import SoraUI

final class DAppTxDetailsViewLayout: UIView {
    let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        return view
    }()

    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorWhite16()!
        view.highlightedFillColor = R.color.colorWhite16()!
        view.cornerRadius = 12.0
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .caption1
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularFootnote
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }

        scrollView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.width.equalTo(self).offset(-32.0)
            make.bottom.equalToSuperview().inset(16.0)
        }

        backgroundView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }

        backgroundView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(0.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(8.0)
        }
    }
}
