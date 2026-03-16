import Foundation

enum StakingKeywordMatcher {
    static func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return false }

        let lowercased = trimmed.lowercased()

        // Check false positive exclusions first
        for exclusion in falsePositiveExclusions {
            if lowercased.contains(exclusion) {
                return false
            }
        }

        // Check CJK keywords (substring match)
        for keyword in cjkKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }

        // Check Latin/Cyrillic keywords (exact match or query starts with keyword+space)
        for keyword in latinKeywords {
            if lowercased == keyword || lowercased.hasPrefix(keyword + " ") {
                return true
            }
        }

        return false
    }

    // MARK: - Private

    private static let falsePositiveExclusions: Set<String> = [
        "mistake",
        "stakeholder",
        "undertake",
        "sweepstake",
        "validate email",
        "validate form",
        "james bond"
    ]

    // CJK keywords use substring matching
    private static let cjkKeywords: [String] = [
        // Japanese
        "\u{30B9}\u{30C6}\u{30FC}\u{30AD}\u{30F3}\u{30B0}",
        "\u{30D0}\u{30EA}\u{30C7}\u{30FC}\u{30BF}",
        "\u{30CE}\u{30DF}\u{30CD}\u{30FC}\u{30B7}\u{30E7}\u{30F3}",
        "\u{59D4}\u{4EFB}",
        "\u{5831}\u{916C}",
        // Korean
        "\u{C2A4}\u{D14C}\u{C774}\u{D0B9}",
        "\u{AC80}\u{C99D}\u{C778}",
        "\u{C9C0}\u{BA85}",
        "\u{C704}\u{C784}",
        "\u{BCF4}\u{C0C1}",
        // Chinese
        "\u{8D28}\u{62BC}",
        "\u{9A8C}\u{8BC1}\u{4EBA}",
        "\u{63D0}\u{540D}",
        "\u{59D4}\u{6258}",
        "\u{5956}\u{52B1}",
        "\u{6536}\u{76CA}"
    ]

    // Latin/Cyrillic keywords use exact or prefix match
    // swiftlint:disable:next function_body_length
    private static let latinKeywords: [String] = [
        // Universal English
        "staking", "stake", "staked", "unstake", "unstaking",
        "restake", "restaking", "nominate", "nominator", "nomination",
        "nomination pool", "nom pool", "validator", "validators", "validate",
        "collator", "collators", "delegate", "delegator",
        "pool staking", "staking pool", "direct staking", "liquid staking",
        "bond", "bonding", "unbond", "unbonding", "rebond", "rebonding",
        "apy", "apr", "yield",
        "dot staking", "ksm staking", "polkadot staking", "kusama staking",
        "staking dashboard", "staking rewards",
        "stake my", "start staking", "how to stake", "where to stake",
        "staking dapp", "staking app",
        "earn rewards", "earn dot", "earn ksm", "passive income",
        "stake tokens", "stake dot", "stake ksm",
        "parachain staking", "dapp staking", "manage staking",
        "my validators", "my nominations",
        // Russian
        "\u{0441}\u{0442}\u{0435}\u{0439}\u{043A}\u{0438}\u{043D}\u{0433}",
        "\u{0441}\u{0442}\u{0435}\u{0439}\u{043A}\u{0430}\u{0442}\u{044C}",
        "\u{043D}\u{0430}\u{0433}\u{0440}\u{0430}\u{0434}\u{044B}",
        "\u{0432}\u{0430}\u{043B}\u{0438}\u{0434}\u{0430}\u{0442}\u{043E}\u{0440}",
        "\u{043D}\u{043E}\u{043C}\u{0438}\u{043D}\u{0430}\u{0442}\u{043E}\u{0440}",
        "\u{0434}\u{0435}\u{043B}\u{0435}\u{0433}\u{0438}\u{0440}\u{043E}\u{0432}\u{0430}\u{0442}\u{044C}",
        // Spanish
        "stakear", "hacer staking", "recompensas", "validador", "nominar", "delegar",
        // French
        "staker", "faire du staking",
        "\u{0072}\u{00E9}\u{0063}\u{006F}\u{006D}\u{0070}\u{0065}\u{006E}\u{0073}\u{0065}\u{0073}",
        "validateur", "nommer",
        "\u{0064}\u{00E9}\u{006C}\u{00E9}\u{0067}\u{0075}\u{0065}\u{0072}",
        // Turkish
        "stake yapmak", "staking yapmak",
        "\u{00F6}\u{0064}\u{00FC}\u{006C}\u{006C}\u{0065}\u{0072}",
        "\u{0064}\u{006F}\u{011F}\u{0072}\u{0075}\u{006C}\u{0061}\u{0079}\u{0131}\u{0063}\u{0131}",
        "\u{0064}\u{0065}\u{006C}\u{0065}\u{0067}\u{0065}",
        // Polish
        "stakowanie",
        "\u{006E}\u{0061}\u{0067}\u{0072}\u{006F}\u{0064}\u{0079}",
        "walidator", "nominacja",
        "\u{0064}\u{0065}\u{006C}\u{0065}\u{0067}\u{006F}\u{0077}\u{0061}\u{0107}",
        // Hungarian
        "stakel\u{00E9}s",
        "jutalmak",
        "\u{0076}\u{0061}\u{006C}\u{0069}\u{0064}\u{00E1}\u{0074}\u{006F}\u{0072}",
        "\u{006E}\u{006F}\u{006D}\u{0069}\u{006E}\u{00E1}\u{006C}\u{00E1}\u{0073}",
        "\u{0064}\u{0065}\u{006C}\u{0065}\u{0067}\u{00E1}\u{006C}\u{00E1}\u{0073}",
        // Indonesian
        "hadiah", "imbalan",
        // Vietnamese
        "ph\u{1EA7}n th\u{01B0}\u{1EDF}ng",
        "x\u{00E1}c th\u{1EF1}c",
        "\u{1EE7}y quy\u{1EC1}n",
        // Italian
        "fare staking", "ricompense", "validatore", "nominare", "delegare",
        // Portuguese
        "fazer staking", "recompensas", "validador", "nomear", "delegar"
    ]
}
