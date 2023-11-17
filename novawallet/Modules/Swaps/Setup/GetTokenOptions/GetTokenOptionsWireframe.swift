import Foundation

final class GetTokenOptionsWireframe {
    let completion: GetTokenOptionsCompletion?

    init(completion: GetTokenOptionsCompletion?) {
        self.completion = completion
    }

    func complete(
        on view: GetTokenOptionsViewProtocol?,
        completion: GetTokenOptionsCompletion?,
        result: GetTokenOptionsResult
    ) {
        view?.controller.dismiss(animated: true) {
            completion?(result)
        }
    }
}

extension GetTokenOptionsWireframe: GetTokenOptionsWireframeProtocol {
    func complete(on view: GetTokenOptionsViewProtocol?, result: GetTokenOptionsResult) {
        complete(on: view, completion: completion, result: result)
    }
}
