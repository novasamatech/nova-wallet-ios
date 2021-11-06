import Foundation
import UIKit.UIPasteboard
import RobinHood

final class AnalyticsRewardDetailsPresenter {
    weak var view: AnalyticsRewardDetailsViewProtocol?
    private let wireframe: AnalyticsRewardDetailsWireframeProtocol
    private let interactor: AnalyticsRewardDetailsInteractorInputProtocol
    private let viewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol
    private let rewardModel: AnalyticsRewardDetailsModel
    private let chain: ChainModel

    init(
        rewardModel: AnalyticsRewardDetailsModel,
        interactor: AnalyticsRewardDetailsInteractorInputProtocol,
        wireframe: AnalyticsRewardDetailsWireframeProtocol,
        viewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol,
        chain: ChainModel
    ) {
        self.rewardModel = rewardModel
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
    }

    private func copyEventId() {
        let eventId = rewardModel.eventId
        UIPasteboard.general.string = eventId

        let locale = view?.selectedLocale ?? .current
        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    private func createExplorerActions() -> [AlertPresentableAction] {
        chain.explorers?.compactMap { explorer in
            guard
                let urlTemplate = explorer.event,
                let url = try? EndpointBuilder(urlTemplate: urlTemplate).buildParameterURL(
                    urlTemplate
                ) else {
                return nil
            }

            return AlertPresentableAction(title: explorer.name) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }
        } ?? []
    }

    private func createCopyAction(locale _: Locale) -> AlertPresentableAction {
        let copyTitle = R.string.localizable
            .commonCopyId()
        return AlertPresentableAction(title: copyTitle) { [weak self] in
            self?.copyEventId()
        }
    }
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViweModel(rewardModel: rewardModel)
        view?.bind(viewModel: viewModel)
    }

    func handleEventIdAction() {
        let locale = view?.selectedLocale ?? .current
        let actions = [createCopyAction(locale: locale)] + createExplorerActions()

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.commonChooseAction(preferredLanguages: locale.rLanguages),
            message: nil,
            actions: actions,
            closeAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        wireframe.present(
            viewModel: viewModel,
            style: .actionSheet,
            from: view
        )
    }
}

extension AnalyticsRewardDetailsPresenter: AnalyticsRewardDetailsInteractorOutputProtocol {}
