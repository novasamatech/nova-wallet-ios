import Foundation

protocol CloudBackupFileModelConverting {
    func convertToPublicInfo(from wallets: Set<MetaAccountModel>) throws -> Set<CloudBackup.WalletPublicInfo>
    func convertFromPublicInfo(models: Set<CloudBackup.WalletPublicInfo>) throws -> Set<MetaAccountModel>
}
