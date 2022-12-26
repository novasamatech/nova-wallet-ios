import Foundation

public struct AssetReceiveInfo: Codable, Equatable {
    public var accountId: String
    public var assetId: String?
    public var amount: Decimal?
    public var details: String?

    public init(accountId: String, assetId: String?, amount: Decimal?, details: String?) {
        self.accountId = accountId
        self.assetId = assetId
        self.amount = amount
        self.details = details
    }
}
