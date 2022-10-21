import UIKit

final class ReferendumFullDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumFullDetailsViewLayout

    let presenter: ReferendumFullDetailsPresenterProtocol

    init(presenter: ReferendumFullDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumFullDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ReferendumFullDetailsViewController: ReferendumFullDetailsViewProtocol {
    func didReceive(proposerModel: ProposerTableCell.Model?) {
        rootView.updateProposerCell(proposerModel: proposerModel)
    }

    func didReceive(json: String?, jsonTitle: String) {
        if let json = json {
            rootView.jsonView.view.text = json
        } else {
            // todo
        }
        rootView.jsonTitle.text = jsonTitle
    }

    func didReceive(
        approveCurve: TitleWithSubtitleViewModel?,
        supportCurve: TitleWithSubtitleViewModel?,
        callHash: TitleWithSubtitleViewModel?
    ) {
        rootView.approveCurve.titleLabel.text = approveCurve?.title
        rootView.approveCurve.detailsLabel.text = approveCurve?.subtitle
        rootView.supportCurve.titleLabel.text = supportCurve?.title
        rootView.supportCurve.detailsLabel.text = supportCurve?.subtitle
        rootView.callHash.titleLabel.text = callHash?.title
        rootView.callHash.detailsLabel.text = callHash?.subtitle
    }
}
