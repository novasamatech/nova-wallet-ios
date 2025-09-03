import Foundation

extension Array where Element == ManagedMetaAccountModel {
    func indexDelegatedAccounts() -> [DelegateIdentifier: ManagedMetaAccountModel] {
        reduce(into: [:]) { acc, wallet in
            if let identifier = wallet.info.getDelegateIdentifier() {
                acc[identifier] = wallet
            }
        }
    }
}
