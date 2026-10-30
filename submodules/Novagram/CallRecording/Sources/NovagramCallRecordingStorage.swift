import Foundation
import AVFoundation

// The recordings folder: <app container>/Library/Application Support/CallRecordings.
// A recording is written into `.partial/<uuid>/<final name>` and moved into the folder once it is finished, so a
// recording cut short by the app being killed (its movie fragments keep it playable) is moved in on the next launch.
public enum NovagramCallRecordingStorage {
    public struct Recording: Equatable {
        public let url: URL
        public let date: Date
        public let duration: Double
        public let isVideo: Bool
        public let size: Int64
    }

    static let folderName = "CallRecordings"
    static let partialFolderName = ".partial"
    static let videoExtension = "mp4"
    static let audioExtension = "m4a"
    static let fallbackName = "Novagram call"
    static let dateFormat = "yyyy-MM-dd HH.mm"
    static let durationAttributeName = "uz.novagram.callrecording.duration"

    public static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = base.appendingPathComponent(NovagramCallRecordingStorage.folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var partialDirectory: URL {
        let url = NovagramCallRecordingStorage.directory.appendingPathComponent(NovagramCallRecordingStorage.partialFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func fileName(peerName: String, date: Date, isVideo: Bool) -> String {
        return NovagramCallRecordingStorage.fileName(peerName: peerName, date: date, isVideo: isVideo, in: NovagramCallRecordingStorage.directory)
    }

    static func fileName(peerName: String, date: Date, isVideo: Bool, in folder: URL) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = NovagramCallRecordingStorage.dateFormat
        let cleaned = peerName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleaned.isEmpty ? NovagramCallRecordingStorage.fallbackName : cleaned
        let base = "\(name) \(formatter.string(from: date))"
        let fileExtension = isVideo ? NovagramCallRecordingStorage.videoExtension : NovagramCallRecordingStorage.audioExtension
        return NovagramCallRecordingStorage.uniqueURL(in: folder, fileName: "\(base).\(fileExtension)").lastPathComponent
    }

    // "<name>.mp4", then "<name> 2.mp4", "<name> 3.mp4", ...
    static func uniqueURL(in folder: URL, fileName: String) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension
        var candidate = folder.appendingPathComponent(fileName)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(index).\(fileExtension)")
            index += 1
        }
        return candidate
    }

    public static func list() -> [Recording] {
        NovagramCallRecordingCenter.recoverInterruptedRecordingsOnce()
        return NovagramCallRecordingStorage.list(in: NovagramCallRecordingStorage.directory)
    }

    static func list(in folder: URL) -> [Recording] {
        let keys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        var result: [Recording] = []
        for url in urls {
            let fileExtension = url.pathExtension.lowercased()
            guard fileExtension == NovagramCallRecordingStorage.videoExtension || fileExtension == NovagramCallRecordingStorage.audioExtension else {
                continue
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
                continue
            }
            let date = values.creationDate ?? values.contentModificationDate ?? Date(timeIntervalSince1970: 0)
            result.append(Recording(url: url, date: date, duration: NovagramCallRecordingStorage.duration(of: url), isVideo: fileExtension == NovagramCallRecordingStorage.videoExtension, size: Int64(values.fileSize ?? 0)))
        }
        result.sort { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            return lhs.url.lastPathComponent > rhs.url.lastPathComponent
        }
        return result
    }

    public static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // Moves a finished file into `folder` under a free name and removes its partial folder.
    static func moveIntoPlace(_ tempURL: URL, folder: URL, duration: Double?) throws -> URL {
        let destination = NovagramCallRecordingStorage.uniqueURL(in: folder, fileName: tempURL.lastPathComponent)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        if let duration {
            NovagramCallRecordingStorage.storeDuration(duration, of: destination)
        }
        return destination
    }

    // Moves every recording left in `.partial` by a killed app into the folder. Never call it while recording.
    static func recoverInterrupted(in folder: URL) {
        let partial = folder.appendingPathComponent(NovagramCallRecordingStorage.partialFolderName, isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: partial, includingPropertiesForKeys: nil) else {
            return
        }
        for entry in entries {
            let files = (try? FileManager.default.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for file in files {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                if size > 0 {
                    _ = try? NovagramCallRecordingStorage.moveIntoPlace(file, folder: folder, duration: nil)
                }
            }
            try? FileManager.default.removeItem(at: entry)
        }
    }

    // The recorder stores the duration in an extended attribute; files without it are measured once by reading
    // their audio track.
    static func duration(of url: URL) -> Double {
        if let stored = NovagramCallRecordingStorage.storedDuration(of: url) {
            return stored
        }
        guard let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 else {
            return 0
        }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        NovagramCallRecordingStorage.storeDuration(duration, of: url)
        return duration
    }

    static func storeDuration(_ duration: Double, of url: URL) {
        var bits = duration.bitPattern.littleEndian
        _ = withUnsafeBytes(of: &bits) { raw in
            setxattr(url.path, NovagramCallRecordingStorage.durationAttributeName, raw.baseAddress, raw.count, 0, 0)
        }
    }

    static func storedDuration(of url: URL) -> Double? {
        var bits: UInt64 = 0
        let size = withUnsafeMutableBytes(of: &bits) { raw in
            getxattr(url.path, NovagramCallRecordingStorage.durationAttributeName, raw.baseAddress, raw.count, 0, 0)
        }
        guard size == MemoryLayout<UInt64>.size else {
            return nil
        }
        let value = Double(bitPattern: UInt64(littleEndian: bits))
        return value.isFinite && value >= 0 ? value : nil
    }
}
