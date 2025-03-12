import UIKit
import SafariServices

final class RampViewController: SFSafariViewController {
    var presenter: RampPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        presenter.setup()
    }

    private func configure() {
        preferredControlTintColor = R.color.colorIconPrimary()!
        preferredBarTintColor = R.color.colorBlurNavigationBackground()!
    }
}

extension RampViewController: RampViewProtocol {}
