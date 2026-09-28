import Foundation
import Foundation_iOS

final class SubtensorValidatorSelectWireframe: ValidatorSelectWireframeProtocol {
    func complete(from view: SubtensorValidatorSelectViewProtocol?) {
        guard let navigation = view?.controller.navigationController,
              let setup = navigation.viewControllers.last(where: { $0 is SubtensorStakingSetupViewController }) else {
            return
        }
        navigation.popToViewController(setup, animated: true)
    }

    func showInfo(from view: SubtensorValidatorSelectViewProtocol?, context: SubtensorValidatorInfoContext) {
        let info = SubtensorValidatorInfoViewController(
            detail: context.detail,
            apy: context.apy,
            locale: context.locale,
            chainAsset: context.chainAsset,
            price: context.price
        )
        view?.controller.navigationController?.pushViewController(info, animated: true)
    }
}
