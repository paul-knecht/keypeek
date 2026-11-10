import Foundation

// Turns an app's bundle identifier (like "com.apple.finder") into a file name
// that is always safe: any unusual character becomes "_", so a file can never
// end up outside the folder it belongs in.
enum SafeFileName {
    static func json(for bundleID: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-")
        let safeName = String(bundleID.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return safeName + ".json"
    }
}
