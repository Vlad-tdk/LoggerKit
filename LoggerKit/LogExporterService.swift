//
//  LogExporterService.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation

/// Service for exporting logs to various formats (CSV, JSON)
public class LogExporterService {
    
    // MARK: - Types
    
    /// Format for log export
    public enum ExportFormat {
        case csv      // Comma-separated values
        case json     // JavaScript Object Notation
    }
    
    /// Structure of a log entry for export
    public struct LogEntry: Codable {
        let timestamp: String
        let category: String
        let level: String
        let message: String
        let source: String
        let line: Int?
    }
    
    /// Export errors
    public enum ExportError: Error, LocalizedError {
        case fileNotFound
        case readError(Error)
        case parseError(String)
        case writeError(Error)
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Log file not found"
            case .readError(let error):
                return "Error reading file: \(error.localizedDescription)"
            case .parseError(let message):
                return "Error parsing log: \(message)"
            case .writeError(let error):
                return "Error writing export file: \(error.localizedDescription)"
            }
        }
    }
    
    /// Export options
    public struct ExportOptions {
        /// Filter by logging level
        let minLevel: Level?
        
        /// Filter by category
        let category: String?
        
        /// Only unique messages
        let uniqueMessagesOnly: Bool
        
        /// Maximum number of entries (nil = no limit)
        let maxEntries: Int?
        
        /// Reverse order (newest entries first)
        let reverseOrder: Bool
        
        /// Initializer with default parameters
        public init(
            minLevel: Level? = nil,
            category: String? = nil,
            uniqueMessagesOnly: Bool = false,
            maxEntries: Int? = nil,
            reverseOrder: Bool = true
        ) {
            self.minLevel = minLevel
            self.category = category
            self.uniqueMessagesOnly = uniqueMessagesOnly
            self.maxEntries = maxEntries
            self.reverseOrder = reverseOrder
        }
    }
    
    // MARK: - Properties
    
    /// Directory for exported files
    private let exportDirectory: URL
    
    // MARK: - Initialization
    
    /// Initializes the export service
    /// - Parameter exportDirectory: Directory to save exported files (default is a temporary directory)
    public init(exportDirectory: URL? = nil) {
        if let directory = exportDirectory {
            self.exportDirectory = directory
        } else {
            let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("LogExports", isDirectory: true)
            try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            self.exportDirectory = tmpDir
        }
    }
    
    // MARK: - Public Methods
    
    /// Exports a log file to the selected format
    /// - Parameters:
    ///   - logFileURL: URL of the log file to export
    ///   - format: Export format (CSV or JSON)
    ///   - options: Export options (filtering, limits, etc.)
    /// - Returns: URL of the exported file or an error
    public func exportLog(
        logFileURL: URL,
        format: ExportFormat,
        options: ExportOptions = ExportOptions()
    ) -> Result<URL, ExportError> {
        do {
            // Check if the file exists
            guard FileManager.default.fileExists(atPath: logFileURL.path) else {
                return .failure(.fileNotFound)
            }
            
            // Read the file content
            let logContent: String
            do {
                logContent = try String(contentsOf: logFileURL, encoding: .utf8)
            } catch {
                return .failure(.readError(error))
            }
            
            // Parse the log
            let logEntries = try parseLogEntries(from: logContent, options: options)
            
            // Export to the selected format
            let exportedFileURL: URL
            switch format {
            case .csv:
                exportedFileURL = try exportToCSV(logEntries, sourceFile: logFileURL)
            case .json:
                exportedFileURL = try exportToJSON(logEntries, sourceFile: logFileURL)
            }
            
            return .success(exportedFileURL)
        } catch let error as ExportError {
            return .failure(error)
        } catch {
            return .failure(.writeError(error))
        }
    }
    
    /// Exports multiple log files into a single file of the selected format
    /// - Parameters:
    ///   - logFileURLs: Array of URLs of log files to export
    ///   - format: Export format (CSV or JSON)
    ///   - options: Export options (filtering, limits, etc.)
    /// - Returns: URL of the exported file or an error
    public func exportLogs(
        logFileURLs: [URL],
        format: ExportFormat,
        options: ExportOptions = ExportOptions()
    ) -> Result<URL, ExportError> {
        do {
            // Collect entries from all files
            var allEntries: [LogEntry] = []
            
            for fileURL in logFileURLs {
                // Check if the file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continue
                }
                
                // Read the file content
                let logContent: String
                do {
                    logContent = try String(contentsOf: fileURL, encoding: .utf8)
                } catch {
                    Log.system.warning("Error reading file \(fileURL.lastPathComponent): \(error)")
                    continue
                }
                
                // Parse the log and add entries
                let entries = try parseLogEntries(from: logContent, options: options)
                allEntries.append(contentsOf: entries)
            }
            
            // If there are no entries, return an error
            if allEntries.isEmpty {
                return .failure(.parseError("Failed to extract log entries from files"))
            }
            
            // Sort all entries
            if options.reverseOrder {
                // Newest entries on top (reverse order)
                allEntries.sort { $0.timestamp > $1.timestamp }
            } else {
                // Oldest entries on top (chronologically)
                allEntries.sort { $0.timestamp < $1.timestamp }
            }
            
            // Limit the number of entries if specified
            if let maxEntries = options.maxEntries, allEntries.count > maxEntries {
                allEntries = Array(allEntries.prefix(maxEntries))
            }
            
            // Form the filename based on the current date and number of files
            let dateString = DateFormatter.compact.string(from: Date())
            let filename = "logs_combined_\(dateString)"
            
            // Export to the selected format
            let exportedFileURL: URL
            switch format {
            case .csv:
                exportedFileURL = try exportToCSV(allEntries, filename: filename)
            case .json:
                exportedFileURL = try exportToJSON(allEntries, filename: filename)
            }
            
            return .success(exportedFileURL)
        } catch let error as ExportError {
            return .failure(error)
        } catch {
            return .failure(.writeError(error))
        }
    }
    
    /// Exports all available log files into a single file of the selected format
    /// - Parameters:
    ///   - format: Export format (CSV or JSON)
    ///   - options: Export options (filtering, limits, etc.)
    /// - Returns: URL of the exported file or an error
    public func exportAllLogs(
        format: ExportFormat,
        options: ExportOptions = ExportOptions()
    ) -> Result<URL, ExportError> {
        let logFiles = Log.allLogFiles
        if logFiles.isEmpty {
            return .failure(.fileNotFound)
        }
        
        return exportLogs(logFileURLs: logFiles, format: format, options: options)
    }
    
    /// Clears the temporary directory with exported files
    public func clearExportDirectory() {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: exportDirectory, includingPropertiesForKeys: nil)
            
            for file in files {
                try fileManager.removeItem(at: file)
            }
            
            Log.system.info("Log export directory cleared")
        } catch {
            Log.system.error("Error clearing export directory: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Parses log lines into structured entries
    /// - Parameters:
    ///   - content: Content of the log file
    ///   - options: Export options for filtering
    /// - Returns: An array of structured log entries
    private func parseLogEntries(from content: String, options: ExportOptions) throws -> [LogEntry] {
        let lines = content.split(separator: "\n")
        var entries: [LogEntry] = []
        var uniqueMessages = Set<String>()
        
        // Regular expression to extract log components
        // Format: [timestamp] [category] [LEVEL] message (source:line)
        let pattern = #"\[(.*?)\]\s*\[(.*?)\]\s*\[(.*?)\]\s*(.*?)\s*\((.*?)(?::(\d+))?\)$"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        
        for line in lines {
            let lineString = String(line)
            let range = NSRange(location: 0, length: lineString.utf16.count)
            
            if let match = regex.firstMatch(in: lineString, options: [], range: range) {
                // Extract log components
                let timestamp = lineString.substring(with: match.range(at: 1))
                let category = lineString.substring(with: match.range(at: 2))
                let levelString = lineString.substring(with: match.range(at: 3))
                let message = lineString.substring(with: match.range(at: 4))
                let source = lineString.substring(with: match.range(at: 5))
                
                var lineNumber: Int? = nil
                if match.numberOfRanges > 6 && match.range(at: 6).location != NSNotFound {
                    lineNumber = Int(lineString.substring(with: match.range(at: 6)))
                }
                
                // Filter by level
                if let minLevel = options.minLevel {
                    let entryLevel = logLevelFromString(levelString)
                    if entryLevel < minLevel {
                        continue
                    }
                }
                
                // Filter by category
                if let categoryFilter = options.category, category != categoryFilter {
                    continue
                }
                
                // Filter unique messages
                if options.uniqueMessagesOnly {
                    if uniqueMessages.contains(message) {
                        continue
                    }
                    uniqueMessages.insert(message)
                }
                
                // Create a log entry
                let entry = LogEntry(
                    timestamp: timestamp,
                    category: category,
                    level: levelString,
                    message: message,
                    source: source,
                    line: lineNumber
                )
                
                entries.append(entry)
            }
        }
        
        // Sorting
        if options.reverseOrder {
            // Newest entries on top (reverse order)
            entries.sort { $0.timestamp > $1.timestamp }
        } else {
            // Oldest entries on top (chronologically)
            entries.sort { $0.timestamp < $1.timestamp }
        }
        
        // Limiting the number of entries
        if let maxEntries = options.maxEntries, entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        return entries
    }
    
    /// Exports log entries to CSV format
    /// - Parameters:
    ///   - entries: Entries to export
    ///   - sourceFile: Source log file to form the export name
    /// - Returns: URL of the exported file
    private func exportToCSV(_ entries: [LogEntry], sourceFile: URL) throws -> URL {
        let filename = sourceFile.deletingPathExtension().lastPathComponent + "_export"
        return try exportToCSV(entries, filename: filename)
    }
    
    /// Exports log entries to CSV format with the specified filename
    /// - Parameters:
    ///   - entries: Entries to export
    ///   - filename: Filename without extension
    /// - Returns: URL of the exported file
    private func exportToCSV(_ entries: [LogEntry], filename: String) throws -> URL {
        let exportFileURL = exportDirectory.appendingPathComponent("\(filename).csv")
        
        var csvString = "Timestamp,Category,Level,Message,Source,Line\n"
        
        for entry in entries {
            // Escape commas and quotes in fields
            let escapedMessage = entry.message.replacingOccurrences(of: "\"", with: "\"\"")
            
            csvString += "\(entry.timestamp),\(entry.category),\(entry.level),\"\(escapedMessage)\",\(entry.source),\(entry.line ?? 0)\n"
        }
        
        do {
            try csvString.write(to: exportFileURL, atomically: true, encoding: .utf8)
            return exportFileURL
        } catch {
            throw ExportError.writeError(error)
        }
    }
    
    /// Exports log entries to JSON format
    /// - Parameters:
    ///   - entries: Entries to export
    ///   - sourceFile: Source log file to form the export name
    /// - Returns: URL of the exported file
    private func exportToJSON(_ entries: [LogEntry], sourceFile: URL) throws -> URL {
        let filename = sourceFile.deletingPathExtension().lastPathComponent + "_export"
        return try exportToJSON(entries, filename: filename)
    }
    
    /// Exports log entries to JSON format with the specified filename
    /// - Parameters:
    ///   - entries: Entries to export
    ///   - filename: Filename without extension
    /// - Returns: URL of the exported file
    private func exportToJSON(_ entries: [LogEntry], filename: String) throws -> URL {
        let exportFileURL = exportDirectory.appendingPathComponent("\(filename).json")
        
        struct ExportedLogData: Encodable {
            let exportDate: String
            let entryCount: Int
            let entries: [LogExporterService.LogEntry]
        }
        
        let exportData = ExportedLogData(
            exportDate: ISO8601DateFormatter().string(from: Date()),
            entryCount: entries.count,
            entries: entries
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(exportData)
            try jsonData.write(to: exportFileURL)
            return exportFileURL
        } catch {
            throw ExportError.writeError(error)
        }
    }
    
    /// Determines the logging level from its string representation
    /// - Parameter levelString: String representation of the level
    /// - Returns: Logging level
    private func logLevelFromString(_ levelString: String) -> Level {
        let normalizedLevel = levelString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Consider the presence of emojis and other style variations
        if normalizedLevel.contains("DEBUG") {
            return .debug
        } else if normalizedLevel.contains("INFO") {
            return .info
        } else if normalizedLevel.contains("WARNING") {
            return .warning
        } else if normalizedLevel.contains("ERROR") {
            return .error
        } else if normalizedLevel.contains("CRITICAL") {
            return .critical
        } else {
            // Default to the lowest level
            return .debug
        }
    }
}

// MARK: - Extensions for working with NSRange

extension String {
    func substring(with nsrange: NSRange) -> String {
        guard let range = Range(nsrange, in: self) else { return "" }
        return String(self[range])
    }
}

// MARK: - Example Usage

/*
 // Create an export service
 let exporter = LogExporterService()
 
 // Export a single log file to CSV
 if let logFileURL = Log.allLogFiles.first {
 let result = exporter.exportLog(
 logFileURL: logFileURL,
 format: .csv,
 options: ExportOptions(
 minLevel: .warning,   // Only warnings and above
 maxEntries: 100,       // Maximum 100 entries
 reverseOrder: true    // Newest entries on top
 )
 )
 
 switch result {
 case .success(let exportedFileURL):
 print("Log successfully exported to CSV: \(exportedFileURL.path)")
 
 // Offer to share the file
 let activityViewController = UIActivityViewController(
 activityItems: [exportedFileURL],
 applicationActivities: nil
 )
 // Show the view controller
 presentingViewController.present(activityViewController, animated: true)
 
 case .failure(let error):
 print("Error exporting log: \(error.localizedDescription)")
 }
 }
 
 // Export all logs to JSON
 let allLogsResult = exporter.exportAllLogs(
 format: .json,
 options: ExportOptions(
 uniqueMessagesOnly: true   // Only unique messages
 )
 )
 
 switch allLogsResult {
 case .success(let exportedFileURL):
 print("All logs successfully exported to JSON: \(exportedFileURL.path)")
 case .failure(let error):
 print("Error exporting all logs: \(error.localizedDescription)")
 }
 
 // Clear the export directory if needed
 exporter.clearExportDirectory()
 */
