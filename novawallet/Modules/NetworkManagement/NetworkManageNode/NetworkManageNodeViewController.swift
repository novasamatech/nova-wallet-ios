import UIKit
import Foundation_iOS

final class NetworkManageNodeViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkManageNodeViewLayout

    let presenter: NetworkManageNodePresenterProtocol

    private var actions: [NetworkManageNodeViewModel.Action] = []
    private var cells: [StackActionCell] = []

    init(presenter: NetworkManageNodePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NetworkManageNodeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

// MARK: NetworkManageNodeViewProtocol

extension NetworkManageNodeViewController: NetworkManageNodeViewProtocol {
    func didReceive(viewModel: NetworkManageNodeViewModel) {
        actions = viewModel.actions

        rootView.titleLabel.text = viewModel.title
        rootView.nodeNameLabel.text = viewModel.nodeName

        replaceCells()
    }
}

// MARK: Private

private extension NetworkManageNodeViewController {
    func replaceCells() {
        cells.forEach { $0.removeFromSuperview() }

        cells = []

        for action in actions {
            let cell = rootView.addAction()

            cell.addTarget(self, action: #selector(actionCell(_:)), for: .touchUpInside)

            cells.append(cell)
        }

        updateCells()
    }

    func updateCells() {
        zip(actions, cells).forEach { actionCell in
            let action = actionCell.0
            let cell = actionCell.1

            let icon = action.negative
                ? action.icon?.tinted(with: R.color.colorIconNegative()!)
                : action.icon?.tinted(with: R.color.colorIconPrimary()!)

            cell.bind(
                title: action.title,
                icon: icon?.withRenderingMode(.alwaysOriginal),
                details: nil
            )

            if action.negative {
                cell.titleLabel.textColor = R.color.colorTextNegative()!
            } else {
                cell.titleLabel.textColor = R.color.colorTextPrimary()!
            }
        }
    }

    @objc func actionCell(_ sender: UIControl) {
        guard
            let cell = sender as? StackActionCell,
            let index = cells.firstIndex(of: cell)
        else {
            return
        }

        actions[index].onSelection()
    }
}

struct NetworkManageNodeViewModel {
    struct Action {
        let title: String
        let icon: UIImage?
        let negative: Bool
        let onSelection: () -> Void
    }

    let title: String
    let nodeName: String
    let actions: [Action]
}
