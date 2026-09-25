import Foundation
import SubstrateSdk

enum SubtensorStakingSubmissionError: Error, Equatable {
    case notEnoughBalanceToStake
    case stakeUnavailable
    case amountTooLow
    case insufficientLiquidity
    case slippageTooHigh
    case priceLimitExceeded
    case subtokenDisabled
    case subnetNotExists
    case hotkeyNotRegistered
    case coldkeySwapInProgress
    case rootStakeLocked
    case temporarilyUnavailable
    case rootClaimTooHeavy
    case safeModeActive
    case feeUnpayable
    case notEnoughStakeToWithdraw
    case tooManyStakingHotkeys
}

protocol SubtensorStakingErrorMapping {
    func mapSubmission(error: Error) -> Error
}

final class SubtensorStakingErrorMapper {
    private static let poolInvalidTransactionCode = 1010
    private static let poolCustomErrorPrefix = "Custom error: "
    private static let coldkeySwapCustomCodes: Set<UInt8> = [0, 21]

    private static func poolCustomErrorCode(from data: String?) -> UInt8? {
        guard let data, data.hasPrefix(poolCustomErrorPrefix) else {
            return nil
        }

        let code = data.dropFirst(poolCustomErrorPrefix.count)

        guard !code.isEmpty, code.allSatisfy({ ("0" ... "9").contains($0) }) else {
            return nil
        }

        return UInt8(code)
    }

    private func map(moduleError: DispatchCallError.ModuleDisplayError) -> SubtensorStakingSubmissionError? {
        switch moduleError.moduleName {
        case SubtensorStakingPallet.name:
            return mapSubtensorModule(errorName: moduleError.errorName)
        case SubtensorStakingPallet.swapPalletName:
            return mapSwapModule(errorName: moduleError.errorName)
        case SystemPallet.name:
            return mapSystemModule(errorName: moduleError.errorName)
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func mapSubtensorModule(errorName: String) -> SubtensorStakingSubmissionError? {
        switch errorName {
        case "NotEnoughBalanceToStake", "InsufficientTaoBalance":
            return .notEnoughBalanceToStake
        case "NotEnoughStakeToWithdraw":
            return .notEnoughStakeToWithdraw
        case "TooManyStakingHotkeys":
            return .tooManyStakingHotkeys
        case "StakeUnavailable":
            return .stakeUnavailable
        case "AmountTooLow":
            return .amountTooLow
        case "InsufficientLiquidity":
            return .insufficientLiquidity
        case "SlippageTooHigh":
            return .slippageTooHigh
        case "SubtokenDisabled":
            return .subtokenDisabled
        case "SubnetNotExists":
            return .subnetNotExists
        case "HotKeyAccountNotExists":
            return .hotkeyNotRegistered
        case "ColdkeySwapAnnounced", "ColdkeySwapDisputed":
            return .coldkeySwapInProgress
        case "RootStakeLocked":
            return .rootStakeLocked
        case "BetaBasketSeedInProgress", "BasketDepositPending":
            return .temporarilyUnavailable
        case "RootClaimTooHeavy":
            return .rootClaimTooHeavy
        default:
            return nil
        }
    }

    private func mapSwapModule(errorName: String) -> SubtensorStakingSubmissionError? {
        switch errorName {
        case "PriceLimitExceeded":
            return .priceLimitExceeded
        case "InsufficientLiquidity":
            return .insufficientLiquidity
        case "InsufficientBalance":
            return .notEnoughBalanceToStake
        case "SubtokenDisabled":
            return .subtokenDisabled
        default:
            return nil
        }
    }

    private func mapSystemModule(errorName: String) -> SubtensorStakingSubmissionError? {
        switch errorName {
        case "CallFiltered":
            return .safeModeActive
        default:
            return nil
        }
    }
}

extension SubtensorStakingErrorMapper: SubtensorStakingErrorMapping {
    func mapSubmission(error: Error) -> Error {
        if
            let dispatchError = error as? DispatchCallError,
            case let .module(moduleError) = dispatchError,
            let mapped = map(moduleError: moduleError.display) {
            return mapped
        }

        if
            let rpcError = error as? JSONRPCError,
            rpcError.code == Self.poolInvalidTransactionCode,
            rpcError.data?.localizedCaseInsensitiveContains("pay some fees") == true {
            return SubtensorStakingSubmissionError.feeUnpayable
        }

        if
            let rpcError = error as? JSONRPCError,
            rpcError.code == Self.poolInvalidTransactionCode,
            let customCode = Self.poolCustomErrorCode(from: rpcError.data),
            Self.coldkeySwapCustomCodes.contains(customCode) {
            return SubtensorStakingSubmissionError.coldkeySwapInProgress
        }

        return error
    }
}

extension SubtensorStakingSubmissionError: ErrorContentConvertible {
    static let maxStakingHotkeys = 256

    // swiftlint:disable:next cyclomatic_complexity
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let title = strings.operationErrorTitle()

        let message: String = switch self {
        case .notEnoughBalanceToStake:
            strings.commonNotEnoughBalanceMessage()
        case .stakeUnavailable:
            strings.stakingSubtensorErrorStakeUnavailable()
        case .amountTooLow:
            strings.amountTooLow()
        case .insufficientLiquidity:
            strings.stakingSubtensorErrorInsufficientLiquidity()
        case .slippageTooHigh:
            strings.stakingSubtensorErrorSlippageTooHigh()
        case .priceLimitExceeded:
            strings.stakingSubtensorErrorPriceLimitExceeded()
        case .subtokenDisabled:
            strings.stakingSubtensorSubnetDisabledMessage()
        case .subnetNotExists:
            strings.stakingSubtensorErrorSubnetNotExists()
        case .hotkeyNotRegistered:
            strings.stakingSubtensorHotkeyNotFoundMessage()
        case .coldkeySwapInProgress:
            strings.stakingSubtensorColdkeySwapMessage()
        case .rootStakeLocked:
            strings.stakingSubtensorErrorRootStakeLocked()
        case .temporarilyUnavailable:
            strings.stakingSubtensorErrorTemporarilyUnavailable()
        case .rootClaimTooHeavy:
            strings.stakingSubtensorErrorClaimTooHeavy()
        case .safeModeActive:
            strings.stakingSubtensorSafeModeMessage()
        case .feeUnpayable:
            strings.stakingSubtensorErrorFeeUnpayable()
        case .notEnoughStakeToWithdraw:
            strings.commonNotEnoughBalanceMessage()
        case .tooManyStakingHotkeys:
            strings.parachainStakingFullMessage(String(Self.maxStakingHotkeys))
        }

        return ErrorContent(title: title, message: message)
    }
}
