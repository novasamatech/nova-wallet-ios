import Foundation

extension StartStakingInfoViewController: SubtensorEarnFlowRoot {
    func startSubnetDiscovery() {
        presenter.startStaking()
    }
}
