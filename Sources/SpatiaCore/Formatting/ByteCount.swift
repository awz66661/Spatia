import Foundation

public enum ByteCount {
    public static func string(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: bytes)
    }
}
