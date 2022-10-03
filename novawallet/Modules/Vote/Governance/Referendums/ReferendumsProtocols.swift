import Foundation

protocol ReferendumsViewProtocol: AnyObject {
    var presenter: ReferendumsPresenterProtocol? { get set }
}

protocol ReferendumsPresenterProtocol: AnyObject {}

protocol ReferendumsInteractorInputProtocol: AnyObject {}

protocol ReferendumsInteractorOutputProtocol: AnyObject {}

protocol ReferendumsWireframeProtocol: AnyObject {}
