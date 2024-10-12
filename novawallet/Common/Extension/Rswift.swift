import RswiftResources

// TODO: Delete file after getting rid of R.swift

extension Bundle {
    /// Returns the string associated with the specified path + key in the receiver's information property list.
    public func infoDictionaryString(path: [String], key: String) -> String? {
        var dict = infoDictionary
        for step in path {
            guard let obj = dict?[step] as? [String: Any] else { return nil }
            dict = obj
        }
        return dict?[key] as? String
    }

    /// Find first bundle and locale for which the table exists
    func firstBundleAndLocale(tableName: String, preferredLanguages: [String]) -> (bundle: Foundation.Bundle, locale: Foundation.Locale)? {
        let hostingBundle = self

        // Filter preferredLanguages to localizations, use first locale
        var languages = preferredLanguages
            .map { Foundation.Locale(identifier: $0) }
            .prefix(1)
            .flatMap { locale -> [String] in
                let language: String?
                if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
                    // Xcode 14 doesn't recognize `Locale.language`, Xcode 14.1 does know `Locale.language`
                    // Xcode 14.1 is first to ship with swift 5.7.1
                    #if swift(>=5.7.1) && !os(Linux)
                        language = locale.language.languageCode?.identifier
                    #else
                        language = locale.languageCode
                    #endif
                } else {
                    language = locale.languageCode
                }
                if hostingBundle.localizations.contains(locale.identifier) {
                    if let language = language, hostingBundle.localizations.contains(language) {
                        return [locale.identifier, language]
                    } else {
                        return [locale.identifier]
                    }
                } else if let language = language, hostingBundle.localizations.contains(language) {
                    return [language]
                } else {
                    return []
                }
            }

        if languages.isEmpty {
            // If there's no languages, use development language as backstop
            if let developmentLocalization = hostingBundle.developmentLocalization {
                languages = [developmentLocalization]
            }
        } else {
            // Insert Base as second item (between locale identifier and languageCode)
            languages.insert("Base", at: 1)

            // Add development language as backstop
            if let developmentLocalization = hostingBundle.developmentLocalization {
                languages.append(developmentLocalization)
            }
        }

        // Find first language for which table exists
        // Note: key might not exist in chosen language (in that case, key will be shown)
        for language in languages {
            if let lproj = hostingBundle.url(forResource: language, withExtension: "lproj"),
               let lbundle = Bundle(url: lproj) {
                let strings = lbundle.url(forResource: tableName, withExtension: "strings")
                let stringsdict = lbundle.url(forResource: tableName, withExtension: "stringsdict")

                if strings != nil || stringsdict != nil {
                    return (lbundle, Foundation.Locale(identifier: language))
                }
            }
        }

        // If table is available in main bundle, don't look for localized resources
        let strings = hostingBundle.url(forResource: tableName, withExtension: "strings", subdirectory: nil, localization: nil)
        let stringsdict = hostingBundle.url(forResource: tableName, withExtension: "stringsdict", subdirectory: nil, localization: nil)
        let hostingLocale = hostingBundle.preferredLocalizations.first.flatMap { Foundation.Locale(identifier: $0) }

        if let hostingLocale = hostingLocale, strings != nil || stringsdict != nil {
            return (hostingBundle, hostingLocale)
        }

        // If table is not found for requested languages, key will be shown
        return nil
    }
}

public extension StringResource {
    func callAsFunction(preferredLanguages: [String]? = nil) -> String {
        String(resource: self, preferredLanguages: preferredLanguages ?? [])
    }
}

public extension StringResource1 {
    func callAsFunction(_ arg1: Arg1, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1)
    }
}

public extension StringResource2 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2)
    }
}

public extension StringResource3 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2, arg3)
    }
}

public extension StringResource4 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2, arg3, arg4)
    }
}

public extension StringResource5 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2, arg3, arg4, arg5)
    }
}

public extension StringResource6 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2, arg3, arg4, arg5, arg6)
    }
}

public extension StringResource7 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    }
}

public extension StringResource8 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    }
}

public extension StringResource9 {
    func callAsFunction(_ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8, _ arg9: Arg9, preferredLanguages: [String]? = nil) -> String {
        String(format: self, preferredLanguages: preferredLanguages ?? [], arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    }
}

// MARK: String

public extension String {
    init(key: StaticString, tableName: String, source: StringResource.Source, developmentValue: String?, locale overrideLocale: Locale?, arguments: [CVarArg]) {
        switch source {
        case let .hosting(bundle):
            // With fallback to developmentValue
            let format = NSLocalizedString(key.description, tableName: tableName, bundle: bundle, value: developmentValue ?? "", comment: "")
            self = String(format: format, locale: overrideLocale ?? Locale.current, arguments: arguments)

        case let .selected(bundle, locale):
            // Don't use developmentValue with selected bundle/locale
            let format = NSLocalizedString(key.description, tableName: tableName, bundle: bundle, value: "", comment: "")
            self = String(format: format, locale: overrideLocale ?? locale, arguments: arguments)

        case .none:
            self = key.description
        }
    }

    init(key: StaticString, tableName: String, source: StringResource.Source, developmentValue: String?, preferredLanguages: [String]? = [], locale overrideLocale: Locale?, arguments: [CVarArg]) {
        guard let (bundle, locale) = source.bundle?.firstBundleAndLocale(tableName: tableName, preferredLanguages: preferredLanguages ?? []) else {
            self = key.description
            return
        }

        self.init(key: key, tableName: tableName, source: .selected(bundle, locale), developmentValue: developmentValue, locale: overrideLocale, arguments: arguments)
    }
}

public extension String {
    init(resource: StringResource, preferredLanguages: [String]? = nil, locale _: Locale? = nil) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages ?? [], locale: nil, arguments: [])
    }

    init<Arg1: CVarArg>(format resource: StringResource1<Arg1>, preferredLanguages: [String]? = nil, locale overrideLocale: Locale? = nil, _ arg1: Arg1) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages ?? [], locale: overrideLocale, arguments: [arg1])
    }

    init<Arg1: CVarArg, Arg2: CVarArg>(format resource: StringResource2<Arg1, Arg2>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2])
    }

    init<Arg1: CVarArg, Arg2: CVarArg, Arg3: CVarArg>(format resource: StringResource3<Arg1, Arg2, Arg3>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2, arg3])
    }

    init<Arg1: CVarArg, Arg2: CVarArg, Arg3: CVarArg, Arg4: CVarArg>(format resource: StringResource4<Arg1, Arg2, Arg3, Arg4>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2, arg3, arg4])
    }

    init<Arg1: CVarArg, Arg2: CVarArg, Arg3: CVarArg, Arg4: CVarArg, Arg5: CVarArg>(format resource: StringResource5<Arg1, Arg2, Arg3, Arg4, Arg5>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2, arg3, arg4, arg5])
    }

    init<Arg1: CVarArg, Arg2: CVarArg, Arg3: CVarArg, Arg4: CVarArg, Arg5: CVarArg, Arg6: CVarArg>(format resource: StringResource6<Arg1, Arg2, Arg3, Arg4, Arg5, Arg6>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2, arg3, arg4, arg5, arg6])
    }

    init<Arg1: CVarArg, Arg2: CVarArg, Arg3: CVarArg, Arg4: CVarArg, Arg5: CVarArg, Arg6: CVarArg, Arg7: CVarArg>(format resource: StringResource7<Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2, arg3, arg4, arg5, arg6, arg7])
    }

    init<Arg1: CVarArg, Arg2: CVarArg, Arg3: CVarArg, Arg4: CVarArg, Arg5: CVarArg, Arg6: CVarArg, Arg7: CVarArg, Arg8: CVarArg>(format resource: StringResource8<Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7, Arg8>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8])
    }

    init<Arg1: CVarArg, Arg2: CVarArg, Arg3: CVarArg, Arg4: CVarArg, Arg5: CVarArg, Arg6: CVarArg, Arg7: CVarArg, Arg8: CVarArg, Arg9: CVarArg>(format resource: StringResource9<Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7, Arg8, Arg9>, preferredLanguages: [String]? = [], locale overrideLocale: Locale? = nil, _ arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8, _ arg9: Arg9) {
        self.init(key: resource.key, tableName: resource.tableName, source: resource.source, developmentValue: resource.developmentValue, preferredLanguages: preferredLanguages, locale: overrideLocale, arguments: [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9])
    }
}
