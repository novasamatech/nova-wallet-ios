import Foundation

struct HydraBalance: Equatable {
    let free: Balance
    let reserved: Balance
    let frozen: Balance

    init(free: Balance, reserved: Balance, frozen: Balance) {
        self.free = free
        self.reserved = reserved
        self.frozen = frozen
    }

    init(currencyData: HydrationApi.CurrencyData) {
        free = currencyData.free
        reserved = currencyData.reserved
        frozen = currencyData.frozen
    }

    init(ormlAccount: OrmlAccount?) {
        free = ormlAccount?.free ?? 0
        reserved = ormlAccount?.reserved ?? 0
        frozen = ormlAccount?.frozen ?? 0
    }

    init(accountInfo: AccountInfo?) {
        free = accountInfo?.data.free ?? 0
        reserved = accountInfo?.data.reserved ?? 0
        frozen = accountInfo?.data.locked ?? 0
    }
}
