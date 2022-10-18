//: A UIKit based Playground for presenting user interface

import UIKit
import SnapKit
import SubstrateSdk
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
// view.addSubview(detailsView)
// detailsView.snp.makeConstraints {
//    $0.centerY.equalToSuperview()
//    $0.leading.trailing.equalToSuperview()
// }

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

// var statusesView = ReferendumTimelineView()
// view.addSubview(statusesView)
// statusesView.snp.makeConstraints {
//    $0.centerY.equalToSuperview()
//    $0.leading.trailing.equalToSuperview()
// }
//
// statusesView.bind(viewModel: .init(title: "Timeline", statuses: [
//    .init(title: "Created", subtitle: .date("Sept 1, 2022 04:44:31"), isLast: false),
//    .init(title: "Created", subtitle: .date("Sept 1, 2022 04:44:31"), isLast: false)
// ]))

// let referendumDAppView = ReferendumDAppView()
// view.addSubview(referendumDAppView)
// referendumDAppView.snp.makeConstraints {
//    $0.centerY.equalToSuperview()
//    $0.leading.trailing.equalToSuperview()
// }
//
// let iconUrl = URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/icons/chains/white/Polkadot.svg")!
// referendumDAppView.bind(viewModel: .init(
//    icon: RemoteImageViewModel(url: iconUrl),
//    title: "Polkassembly",
//    subtitle: "Comment and react"
// ))

let referendumDetailsTitleView = ReferendumDetailsTitleView()
view.addSubview(referendumDetailsTitleView)
referendumDetailsTitleView.snp.makeConstraints {
    $0.centerY.equalToSuperview()
    $0.leading.trailing.equalToSuperview()
}

referendumDetailsTitleView.backgroundColor = .darkGray

func generateMetaAccount(with chainAccounts: Set<ChainAccountModel> = []) -> MetaAccountModel {
    MetaAccountModel(
        metaId: UUID().uuidString,
        name: UUID().uuidString,
        substrateAccountId: Data.random(of: 32)!,
        substrateCryptoType: 0,
        substratePublicKey: Data.random(of: 32)!,
        ethereumAddress: Data.random(of: 20)!,
        ethereumPublicKey: Data.random(of: 32)!,
        chainAccounts: chainAccounts,
        type: .secrets
    )
}

let wallet = generateMetaAccount()
let optIcon = wallet.walletIdenticonData().flatMap { try? PolkadotIconGenerator().generateFromAccountId($0) }
let iconViewModel = optIcon.map { DrawableIconViewModel(icon: $0) }

referendumDetailsTitleView.bind(viewModel:
    .init(
        track: .init(
            titleIcon: .init(title: "main agenda", icon: nil),
            referendumNumber: "224"
        ),
        accountIcon: iconViewModel,
        accountName: "RTTI-5220",
        title: "Polkadot and Kusama participation in the 10th Pais Digital Chile Summit.",
        description: "The Sovereign Nature Initiative transfers, Governance, Sovereign Nature Initiative (SNI) is a non-profit foundation that has" +
            "brought together multiple partners and engineers from the лоалыво одыо лоаыдвлоадо",
        buttonText: "Read more >"
    ))
PlaygroundPage.current.liveView = view
