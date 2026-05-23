import Foundation

#if swift(>=4.1)
    // compactMap supported
#else
    extension Sequence {
        func compactMap<ElementOfResult>(_ transform: (Self.Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
            return try flatMap(transform)
        }
    }
#endif

extension String {
    var ifNotEmpty: String? {
        return count > 0 ? self : nil
    }
}

func localized(_ zh: String, _ en: String) -> String {
    AppSettings.appLanguage == .chinese ? zh : en
}
