//: A UIKit based Playground for presenting user interface

import UIKit
import SnapKit
import PlaygroundSupport

private func registerFonts() {
    registerFont(name: "PublicSans-Medium")
    registerFont(name: "PublicSans-ExtraLight")
    registerFont(name: "PublicSans-SemiBold")
    registerFont(name: "PublicSans-Regular")
    registerFont(name: "PublicSans-ExtraBold")
    registerFont(name: "PublicSans-Bold")
}

private func registerFont(name: String) {
    let cfURL = Bundle.main.url(
        forResource: name,
        withExtension: "otf"
    )! as CFURL

    CTFontManagerRegisterFontsForURL(cfURL, CTFontManagerScope.process, nil)
}

registerFonts()
let view = UIView()
view.backgroundColor = .black
view.frame = .init(
    origin: .zero,
    size: .init(width: 360, height: 800)
)

var detailsView = ReferendumVotingStatusDetailsView()
view.addSubview(detailsView)
detailsView.snp.makeConstraints {
    $0.centerY.equalToSuperview()
    $0.leading.trailing.equalToSuperview()
}

let status = ReferendumVotingStatusView.Model(
    status: .init(name: "PASSING", kind: .positive),
    time: .init(titleIcon: .init(title: "Approve in 03:59:59", icon: R.image.iconFire()), isUrgent: true),
    title: "Voting status"
)
let votingProgress = VotingProgressView.Model(
    ayeProgress: "Aye: 99.9%",
    passProgress: "To pass: 50%",
    nayProgress: "Nay: 0.1%",
    thresholdModel: .init(titleIcon: .init(title: "Threshold reached", icon: R.image.iconCheckmark()?.withTintColor(R.color.colorDarkGreen()!)), value: 0.5),
    progress: 0.9
)
detailsView.bind(viewModel: .init(
    status: status,
    votingProgress: votingProgress,
    aye: .init(
        title: "Aye",
        votes: "25,354.16 votes",
        tokens: "16,492 KSM"
    ),
    nay: .init(
        title: "Nay",
        votes: "1.5 votes",
        tokens: "149 KSM"
    ),
    buttonText: "Vote"
))

PlaygroundPage.current.liveView = view
