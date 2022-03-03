import Foundation

protocol NftListItemViewProtocol: AnyObject {
    func setName(_ name: String?)
    func setLabel(_ label: String?)
    func setMedia(_ media: NftMediaViewModelProtocol?)
}

protocol NftListMetadataViewModelProtocol {
    func load(on view: NftListItemViewProtocol, completion: ((Error?) -> Void)?)
    func cancel(on view: NftListItemViewProtocol)
}
