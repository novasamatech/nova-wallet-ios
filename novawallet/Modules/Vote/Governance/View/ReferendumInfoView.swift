import UIKit

final class ReferendumInfoView: UIView {
    let statusLabel: UILabel = .init(style: .neutralStatusLabel)

    let timeView: IconDetailsView = .create {
        $0.mode = .detailsIcon
        $0.detailsLabel.apply(style: .timeViewLabel)
        $0.spacing = 5
    }

    let titleLabel: UILabel = .init(style: .title)

    let trackNameView: BorderedIconLabelView = .create {
        $0.iconDetailsView.spacing = 6
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.iconDetailsView.detailsLabel.apply(style: .track)
    }

    let numberView: BorderedLabelView = .create {
        $0.titleLabel.apply(style: .track)
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
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
        let content = UIView.vStack(
            spacing: 8,
            [
                UIView.hStack([
                    statusLabel,
                    UIView(),
                    timeView
                ]),
                titleLabel,
                UIView.hStack([
                    trackNameView,
                    numberView
                ])
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension UILabel.Style {
    static let positiveStatusLabel = UILabel.Style(
        textColor: R.color.colorDarkGreen(),
        font: .semiBoldCaps1
    )
    static let neutralStatusLabel = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .semiBoldCaps1
    )
    static let negativeStatusLabel = UILabel.Style(
        textColor: R.color.colorRedFF3A69(),
        font: .semiBoldCaps1
    )
    static let timeViewLabel = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
    static let activeTimeViewLabel = UILabel.Style(
        textColor: R.color.colorDarkYellow(),
        font: .caption1
    )

    static let title = UILabel.Style(
        textColor: .white,
        font: .regularSubheadline
    )

    static let track = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .semiBoldCaps1
    )
}

import SwiftUI

struct ReferendumInfoViewSwiftUI: UIViewControllerRepresentable {
    let closure: (UIView) -> Void

    func makeUIViewController(context _: Context) -> some UIViewController {
        let vc = UIViewController()
        closure(vc.view)
        return vc
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}

struct ReferendumInfoViewSwiftUI_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            ReferendumInfoViewSwiftUI { container in
                let refView: ReferendumInfoView = .create {
                    $0.statusLabel.text = "preparing".uppercased()
                    $0.timeView.detailsLabel.text = "Deciding in 02:02:11"
                    $0.titleLabel.text = "Reduce validationUpgradeCooldown to 6 hours"
                    $0.trackNameView.iconDetailsView.detailsLabel.text = "fellowship: whitelist"
                    $0.numberView.titleLabel.text = "#234"
                }

                container.addSubview(refView)
                refView.snp.makeConstraints {
                    $0.edges.equalToSuperview()
                }
            }
        }
    }
}
