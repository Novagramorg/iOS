import Foundation

private final class TONWalletKitBundleFinder {
}

extension Bundle {
    static let module: Bundle = {
        let bundleName = "TONWalletKitResources"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: TONWalletKitBundleFinder.self).resourceURL,
            Bundle.main.bundleURL
        ]

        for candidate in candidates {
            guard let candidate else {
                continue
            }
            let bundleURL = candidate.appendingPathComponent(bundleName + ".bundle")
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        fatalError("Unable to find \(bundleName).bundle")
    }()
}
