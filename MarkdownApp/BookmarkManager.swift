
import Foundation

struct BookmarkManager {
    private static let userDefaultsKey = "directoryBookmark"

    static func saveBookmark(for url: URL) {
        do {
            #if os(macOS)
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            UserDefaults.standard.set(bookmarkData, forKey: userDefaultsKey)
        } catch {
            print("无法保存书签: \(error.localizedDescription)")
        }
    }

    static func loadUrlFromBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        
        do {
            var isStale = false
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            #else
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            #endif
            
            if isStale {
                // 如果书签已过期，我们应该尝试刷新它，但为简单起见，我们暂时只清除它
                print("书签已过期。")
                clearBookmark()
                return nil
            }
            
            return url
        } catch {
            print("无法解析书签: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
