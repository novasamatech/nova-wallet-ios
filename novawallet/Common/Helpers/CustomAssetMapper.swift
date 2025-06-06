import Foundation
import SubstrateSdk

struct CustomAssetMapper {
    enum MapperError: Error {
        case unexpectedType(_ type: String?)
        case invalidJson(_ type: String?)
    }

    let type: String?
    let typeExtras: AssetTypeExtras?

    func mapAssetWithExtras<T>(
        nativeHandler: () -> T,
        statemineHandler: (StatemineAssetExtras) -> T,
        ormlHandler: (OrmlTokenExtras) -> T,
        evmHandler: (AccountId) -> T,
        evmNativeHandler: () -> T,
        equilibriumHandler: (EquilibriumAssetExtras) -> T
    ) throws -> T {
        let wrappedType: AssetType? = try type.map { value in
            if let typeValue = AssetType(rawValue: value) {
                return typeValue
            } else {
                throw MapperError.unexpectedType(type)
            }
        }

        switch wrappedType {
        case .statemine:
            guard let wrappedExtras = try? typeExtras?.map(to: StatemineAssetExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return statemineHandler(wrappedExtras)
        case .orml:
            guard let wrappedExtras = try? typeExtras?.map(to: OrmlTokenExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return ormlHandler(wrappedExtras)
        case .evmAsset:
            guard let contractAddress = typeExtras?.evmContractAddress else {
                throw MapperError.invalidJson(type)
            }

            let accountId = try contractAddress.toAccountId(using: .ethereum)

            return evmHandler(accountId)
        case .evmNative:
            return evmNativeHandler()
        case .equilibrium:
            guard let wrappedExtras = try? typeExtras?.map(to: EquilibriumAssetExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return equilibriumHandler(wrappedExtras)
        case .none:
            return nativeHandler()
        }
    }

    func mapAsset<T>(
        nativeHandler: () -> T,
        statemineHandler: () -> T,
        ormlHandler: () -> T,
        evmHandler: () -> T,
        evmNativeHandler: () -> T,
        equilibriumHandler: () -> T
    ) throws -> T {
        let wrappedType: AssetType? = try type.map { value in
            if let typeValue = AssetType(rawValue: value) {
                return typeValue
            } else {
                throw MapperError.unexpectedType(type)
            }
        }

        switch wrappedType {
        case .statemine:
            return statemineHandler()
        case .orml:
            return ormlHandler()
        case .evmAsset:
            return evmHandler()
        case .evmNative:
            return evmNativeHandler()
        case .equilibrium:
            return equilibriumHandler()
        case .none:
            return nativeHandler()
        }
    }
}

extension CustomAssetMapper {
    func historyAssetId() throws -> String? {
        try mapAssetWithExtras(
            nativeHandler: { nil },
            statemineHandler: { $0.assetId },
            ormlHandler: { $0.currencyIdScale },
            evmHandler: { try? $0.toAddress(using: .ethereum) },
            evmNativeHandler: { nil },
            equilibriumHandler: { String($0.assetId) }
        )
    }

    func transfersEnabled() throws -> Bool {
        try mapAssetWithExtras(
            nativeHandler: { true },
            statemineHandler: { _ in true },
            ormlHandler: { $0.transfersEnabled ?? true },
            evmHandler: { _ in true },
            evmNativeHandler: { true },
            equilibriumHandler: { $0.transfersEnabled ?? true }
        )
    }
}
