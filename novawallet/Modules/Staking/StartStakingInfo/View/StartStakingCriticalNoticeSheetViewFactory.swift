import Foundation

struct StartStakingCriticalNoticeSheetViewFactory {
    static func createView(
        title: String,
        body: String,
        onCancel: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) -> StartStakingCriticalNoticeSheetViewProtocol? {
        let presenter = StartStakingCriticalNoticeSheetPresenter(
            onCancel: onCancel,
            onContinue: onContinue
        )

        let view = StartStakingCriticalNoticeSheetViewController(
            presenter: presenter,
            title: title,
            body: body
        )

        presenter.view = view

        return view
    }
}
