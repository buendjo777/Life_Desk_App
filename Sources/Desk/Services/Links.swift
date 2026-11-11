import AppKit

/// Hand-off links, all built by code from ids. No link ever comes from email text.
enum Links {
    /// `https://mail.google.com/mail/u/0/#all/<thread id>`. The id must be plain hex.
    static func gmail(thread: String) -> URL? {
        guard !thread.isEmpty, thread.allSatisfy(\.isHexDigit) else { return nil }
        return URL(string: "https://mail.google.com/mail/u/0/#all/\(thread)")
    }

    /// `https://claude.ai/new?q=<seed>`. The seed is Jose's own work order: it names the item
    /// and where it lives, and never carries third-party text.
    static func claude(seed: String) -> URL? {
        guard !isSensitive(seed) else { return nil }
        var components = URLComponents(string: "https://claude.ai/new")
        components?.queryItems = [URLQueryItem(name: "q", value: seed)]
        return encodingPlus(components)
    }

    /// `https://wa.me/<digits>?text=<message>`. Nothing is sent until Jose presses send in WhatsApp.
    static func whatsApp(phone: String, text: String) -> URL? {
        let digits = phone.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return nil }
        var components = URLComponents(string: "https://wa.me/\(digits)")
        components?.queryItems = [URLQueryItem(name: "text", value: text)]
        return encodingPlus(components)
    }

    /// `URLComponents` leaves "+" as it is, and the receiving page reads it as a space.
    private static func encodingPlus(_ components: URLComponents?) -> URL? {
        guard var components else { return nil }
        let query = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components.percentEncodedQuery = query
        return components.url
    }

    /// No seed for anything about money, health or credentials (SPEC "Hand-offs").
    static func isSensitive(_ text: String) -> Bool {
        let words = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        return !words.isDisjoint(with: sensitiveWords) || text.contains("€") || text.contains("$")
    }

    private static let sensitiveWords: Set<String> = [
        "pay", "paid", "payment", "payments", "invoice", "bank", "iban", "salary", "tax", "taxes", "rent", "fee", "fees", "money", "bizum",
        "password", "passwords", "token", "tokens", "credential", "credentials", "login", "pin",
        "doctor", "medical", "health", "prescription", "therapy", "diagnosis", "clinic", "hospital",
    ]

    /// An id that is safe to name in a seed: letters, digits, dashes and underscores only.
    static func safeID(_ id: String) -> String? {
        !id.isEmpty && id.count <= 64 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } ? id : nil
    }

    /// `obsidian://open?vault=<vault folder name>&file=<path>`.
    static func obsidian(vault: String, file: String) -> URL? {
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "vault", value: vault), URLQueryItem(name: "file", value: file)]
        return components.url
    }

    /// A link from Jose's own settings or boards; only http(s) is opened.
    static func web(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    @MainActor
    static func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
