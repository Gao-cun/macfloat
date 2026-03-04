import AppKit
import Foundation

struct NowPlayingService {
    func currentSummary() -> NowPlayingSummary? {
        if let music = queryMusicApp() {
            return music
        }
        if let spotify = querySpotify() {
            return spotify
        }
        return nil
    }

    private func queryMusicApp() -> NowPlayingSummary? {
        guard isRunning(bundleIdentifier: "com.apple.Music") else { return nil }
        let script = """
        tell application "Music"
            if player state is playing then
                return (name of current track) & "||" & (artist of current track) & "||Apple Music"
            end if
        end tell
        return ""
        """
        return execute(script: script)
    }

    private func querySpotify() -> NowPlayingSummary? {
        guard isRunning(bundleIdentifier: "com.spotify.client") else { return nil }
        let script = """
        tell application "Spotify"
            if player state is playing then
                return (name of current track) & "||" & (artist of current track) & "||Spotify"
            end if
        end tell
        return ""
        """
        return execute(script: script)
    }

    private func isRunning(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    private func execute(script: String) -> NowPlayingSummary? {
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        guard let text = result.stringValue, !text.isEmpty else { return nil }
        let components = text.components(separatedBy: "||")
        guard let title = components.first, !title.isEmpty else { return nil }
        let artist = components.count > 1 ? components[1] : ""
        let source = components.count > 2 ? components[2] : "正在播放"
        return NowPlayingSummary(title: title, artist: artist, sourceName: source)
    }
}
