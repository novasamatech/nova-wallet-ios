import Foundation
import UIKit

final class ReferendumsViewManager: NSObject {
    let tableView: UITableView
    let chainSelectionView: VoteChainViewProtocol

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                tableView.reloadData()
            }
        }
    }

    weak var presenter: ReferendumsPresenterProtocol?
    private weak var parent: ControllerBackedProtocol?

    init(tableView: UITableView, chainSelectionView: VoteChainViewProtocol, parent: ControllerBackedProtocol) {
        self.tableView = tableView
        self.chainSelectionView = chainSelectionView
        self.parent = parent

        super.init()
    }
}

// TODO: Implement protocols when data source defined
extension ReferendumsViewManager: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.applyStyle()
        cell.view.bind(viewModel: createSample1())
        cell.view.referendumInfoView.statusLabel.apply(style: .positiveStatusLabel)
        cell.view.referendumInfoView.timeView.detailsLabel.apply(style: .activeTimeViewLabel)
        return cell
    }

    private func createSample1() -> ReferendumView.Model {
        let referendumInfo = ReferendumInfoView.Model(
            status: "passing".uppercased(),
            time: "Approve in 3:59:59",
            timeImage: R.image.iconFire(),
            title: "Runtime upgrade to 9280",
            trackName: "main agenda".uppercased(),
            trackImage: nil,
            number: "#228"
        )
        let progress = VotingProgressView.Model(
            ayeProgress: "Aye: 80%",
            passProgress: "To pass: 90%",
            nayProgress: "Nay: 1.1%",
            thresholdModel: .init(
                image: R.image.iconCheckmark(),
                text: "Threshold: 16,492 of 15,392.5 KSM",
                value: 0.5
            ),
            progress: 0.8
        )
        return ReferendumView.Model(
            referendumInfo: referendumInfo,
            progress: progress,
            yourVotes: nil
        )
    }
}

extension ReferendumsViewManager: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        nil
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        0.0
    }
}

extension ReferendumsViewManager: ReferendumsViewProtocol {
    func didReceiveChainBalance(viewModel: ChainBalanceViewModel) {
        chainSelectionView.bind(viewModel: viewModel)
    }
}

extension ReferendumsViewManager: VoteChildViewProtocol {
    var isSetup: Bool {
        parent?.isSetup ?? false
    }

    var controller: UIViewController {
        parent?.controller ?? UIViewController()
    }

    func bind() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClassForCell(ReferendumTableViewCell.self)

        tableView.reloadData()
    }

    func unbind() {
        tableView.dataSource = nil
        tableView.delegate = nil
        tableView.unregisterClassForCell(ReferendumTableViewCell.self)

        tableView.reloadData()
    }
}
