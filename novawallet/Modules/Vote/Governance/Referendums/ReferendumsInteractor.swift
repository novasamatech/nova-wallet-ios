import Foundation

final class ReferendumsInteractor {
    weak var presenter: ReferendumsInteractorOutputProtocol?
}

extension ReferendumsInteractor: ReferendumsInteractorInputProtocol {}
