import Foundation

/// Appends to ~/Library/Logs/barn.log (Console.app shows it under Log Reports).
enum Log {
    private static let queue = DispatchQueue(label: "barn.log")
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/barn.log")

    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        queue.async {
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile()
                fh.write(Data(line.utf8))
                try? fh.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}
