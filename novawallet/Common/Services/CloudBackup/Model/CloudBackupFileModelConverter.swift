import Foundation

protocol CloudBackupFileModelConverting {
    func convert(wallets: Set<MetaAccountModel>) throws -> Set<CloudBackup.FileModel.WalletPublicInfo>
    func convert(fileModels: Set<CloudBackup.FileModel.WalletPublicInfo>) throws -> Set<MetaAccountModel>
}
