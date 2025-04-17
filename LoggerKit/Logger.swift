//
//  Logger.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation

/// Logger that can output messages to the console and/or a file with configurable file size limit
public struct Logger {
    
    // MARK: - Properties
    
    private let subsystem: String        // Subsystem (usually the app identifier)
    private let category: String         // Log category (e.g., "Network", "Database")
    private let minLevel: Level          // Minimum level for logging
    private let fileURL: URL?            // URL of the log file
    private let maxFileSize: UInt64      // Maximum log file size in bytes
    private let maxBackupCount: Int      // Maximum number of backup files
    private let queue: DispatchQueue     // Logging queue
    private let style: LogStyle          // Log level formatting style
    private let destinations: LogDestination // Log destinations
    
    // Cached file size - we use a global cache since the struct is immutable
    private let fileId: String  // Unique identifier for file size cache
    
    // MARK: - Static file size cache
    private static var fileSizeCache: [String: UInt64] = [:]
    private static let fileAccessQueue = DispatchQueue(label: "com.logger.fileAccess")
    
    // MARK: - Initialization
    
    /// Initializes a new logger
    /// - Parameters:
    ///   - subsystem: Subsystem identifier (e.g. com.company.app)
    ///   - category: Category for this logger (e.g. "Network", "Database")
    ///   - minLevel: Minimum logging level (default: .debug)
    ///   - writeToFile: Whether to write logs to a file (default: false)
    ///   - directory: Directory for log files (default: Documents directory)
    ///   - filename: Log file name (default: "app.log")
    ///   - maxFileSize: Maximum log file size in bytes before rotation (default: 1MB)
    ///   - maxBackupCount: Maximum number of log backup files (default: 5)
    ///   - style: Log level formatting style (default: .plain)
    ///   - destinations: Log destinations (default: all)
    public init(
        subsystem: String,
        category: String,
        minLevel: Level = .debug,
        writeToFile: Bool = false,
        directory: URL? = nil,
        filename: String = "app.log",
        maxFileSize: UInt64 = 1_024 * 1_024, // Default 1MB
        maxBackupCount: Int = 5,
        style: LogStyle = .plain,
        destinations: LogDestination = .all
    ) {
        self.subsystem = subsystem
        self.category = category
        self.minLevel = minLevel
        self.maxFileSize = maxFileSize
        self.maxBackupCount = maxBackupCount
        self.style = style
        self.destinations = destinations
        
        // Create a dedicated serial queue for logging operations
        self.queue = DispatchQueue(label: "com.logger.\(subsystem).\(category)", qos: .utility)
        
        // Set up the log file URL if writing to file is enabled
        var tmpFileURL: URL? = nil
        if writeToFile || destinations.contains(.file) {
            let baseDir = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logsDirectory = baseDir.appendingPathComponent("Logs", isDirectory: true)
            
            // Create log directory if it does not exist
            do {
                try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            } catch {
#if DEBUG
                print("Logger failed to create Logs directory: \(error.localizedDescription)")
#endif
            }
            
            tmpFileURL = logsDirectory.appendingPathComponent(filename)
            if let fileURL = tmpFileURL {
                print("Logger fileURL initialized at: \(fileURL.path)")
            }
        }
        self.fileURL = tmpFileURL
        
        // Create a unique identifier for the file
        self.fileId = "\(subsystem).\(category).\(String(describing: fileURL?.absoluteString ?? ""))"
        
        // Initialize file size cache if the file exists
        if let fileURL = self.fileURL {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? UInt64 {
                    Logger.fileSizeCache[fileId] = fileSize
                } else {
#if DEBUG
                    print("Logger: attributes[.size] is not UInt64, got: \(String(describing: attributes[.size]))")
#endif
                    Logger.fileSizeCache[fileId] = 0
                }
            } catch {
#if DEBUG
                print("Logger: failed to get file attributes: \(error.localizedDescription)")
#endif
                Logger.fileSizeCache[fileId] = 0
            }
        }
    }
    
    // MARK: - Upload Configuration
    
    /// Global upload endpoint for log uploads
    public static var uploadEndpoint: URL? = nil
    
    /// Creates and returns a configured instance of `LogUploaderService`.
    ///
    /// This method can either use the provided `uploader` instance or create a new one using
    /// the specified `endpoint`, `authHeaders`, and `timeoutInterval`.
    ///
    /// - Parameters:
    ///   - endpoint: The server URL to which logs will be uploaded. If `nil`, the value from `Logger.uploadEndpoint` is used.
    ///   - authHeaders: Optional HTTP headers for authentication or additional metadata.
    ///   - timeoutInterval: Timeout interval for the upload request (default is 60 seconds).
    ///   - uploader: Optional custom uploader instance. If provided, this instance is returned directly.
    ///
    /// - Returns: A configured instance of `LogUploaderService` or `nil` if no valid endpoint is available.
    
    public static func makeUploader(
        endpoint: URL? = Logger.uploadEndpoint,
        authHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 60.0,
        uploader: LogUploaderService? = nil
    ) -> LogUploaderService? {
        if let uploader = uploader {
            return uploader
        }
        guard let url = endpoint else { return nil }
        return LogUploaderService(endpoint: url, authHeaders: authHeaders, timeoutInterval: timeoutInterval)
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message
    /// - Parameters:
    ///   - message: Message text
    ///   - file: Source file (auto)
    ///   - function: Source function (auto)
    ///   - line: Line number (auto)
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    /// Log an informational message
    /// - Parameters:
    ///   - message: Message text
    ///   - file: Source file (auto)
    ///   - function: Source function (auto)
    ///   - line: Line number (auto)
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    /// Log a warning
    /// - Parameters:
    ///   - message: Message text
    ///   - file: Source file (auto)
    ///   - function: Source function (auto)
    ///   - line: Line number (auto)
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    /// Log an error
    /// - Parameters:
    ///   - message: Message text
    ///   - file: Source file (auto)
    ///   - function: Source function (auto)
    ///   - line: Line number (auto)
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    /// Log a critical error
    /// - Parameters:
    ///   - message: Message text
    ///   - file: Source file (auto)
    ///   - function: Source function (auto)
    ///   - line: Line number (auto)
    public func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, file: file, function: function, line: line)
    }
    
    // MARK: - Private Helper Methods
    
    /// Core logging method
    /// - Parameters:
    ///   - message: Log message
    ///   - level: Log level
    ///   - file: File name
    ///   - function: Function name
    ///   - line: Line number
    private func log(_ message: String, level: Level, file: String, function: String, line: Int) {
        // Skip if the log level is below the minimum
        guard level >= minLevel else { return }
        
        // Capture local copies for the closure
        let subsystem = self.subsystem
        let category = self.category
        let fileURL = self.fileURL
        let fileId = self.fileId
        let maxFileSize = self.maxFileSize
        let maxBackupCount = self.maxBackupCount
        let style = self.style
        let destinations = self.destinations
        
        queue.async {
            // Format the time using a thread-safe formatter
            let timestamp = Logger.threadLocalDateFormatter.string(from: Date())
            
            // Extract the file name from the path
            let filename = URL(fileURLWithPath: file).lastPathComponent
            
            // Format the log message using the selected style
            let logLevelString = style.apply(to: level)
            let formattedMessage = "[\(timestamp)] [\(category)] [\(logLevelString)] \(message) (\(filename):\(line))"
            
            // Output to console in DEBUG mode or if destination is set
#if DEBUG
            if destinations.contains(.console) {
                print(formattedMessage)
            }
#endif
            
            // Write to file if enabled
            if destinations.contains(.file), let fileURL = fileURL {
                do {
                    try Logger.writeToFile(formattedMessage + "\n", fileURL: fileURL, fileId: fileId, maxFileSize: maxFileSize, maxBackupCount: maxBackupCount)
                } catch {
#if DEBUG
                    print("Failed to write log to file: \(error.localizedDescription)")
#endif
                }
            }
            
            // Send to all registered adapters if enabled
            if destinations.contains(.adapters) {
                Logger.notifyAdapters(message: message, level: level, subsystem: subsystem, category: category, file: file, function: function, line: line)
            }
        }
    }
    
    // MARK: - Static properties & methods
    
    // Thread-local storage for DateFormatter
    private static var threadLocalDateFormatter: DateFormatter {
        let threadDictionary = Thread.current.threadDictionary
        let formatterKey = "com.logger.dateformatter"
        
        if let formatter = threadDictionary[formatterKey] as? DateFormatter {
            return formatter
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            threadDictionary[formatterKey] = formatter
            return formatter
        }
    }
    
    /// Writes a log message to a file
    /// - Parameters:
    ///   - string: The string to write
    ///   - fileURL: Log file URL
    ///   - fileId: File ID for size cache
    ///   - maxFileSize: Max file size
    ///   - maxBackupCount: Max backup files
    private static func writeToFile(_ string: String, fileURL: URL, fileId: String, maxFileSize: UInt64, maxBackupCount: Int) throws {
        var result: Result<Void, Error>!
        fileAccessQueue.sync {
            result = Result {
                print("Attempting to write to: \(fileURL.path)")
                print("File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
                let directoryURL = fileURL.deletingLastPathComponent()
                if !FileManager.default.isWritableFile(atPath: directoryURL.path) {
                    throw NSError(domain: "FileErrorDomain", code: 1001,
                                  userInfo: [NSLocalizedDescriptionKey: "No write access to directory: \(directoryURL.path)"])
                }
                
                let currentSize = fileSizeCache[fileId] ?? 0
                
                if currentSize >= maxFileSize {
                    do {
                        rotateLogFile(fileURL, maxBackupCount: maxBackupCount)
                        fileSizeCache[fileId] = 0
                    }
                }
                
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        try Data().write(to: fileURL, options: .atomic)
                    } catch {
                        throw NSError(domain: "FileErrorDomain", code: 1003,
                                      userInfo: [NSLocalizedDescriptionKey: "Failed to create file: \(error.localizedDescription)"])
                    }
                }
                
                let fileHandle: FileHandle
                do {
                    fileHandle = try FileHandle(forWritingTo: fileURL)
                } catch {
                    throw NSError(domain: "FileErrorDomain", code: 1004,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to open file for writing: \(error.localizedDescription)"])
                }
                
                print("Writing string length: \(string.count), fileId: \(fileId)")
                
                do {
                    try fileHandle.seekToEnd()
                    
                    guard let data = string.data(using: .utf8) else {
                        throw NSError(domain: "FileErrorDomain", code: 1005,
                                      userInfo: [NSLocalizedDescriptionKey: "Failed to convert string to UTF-8 data"])
                    }
                    
                    try fileHandle.write(contentsOf: data)
                    
                    fileSizeCache[fileId] = (fileSizeCache[fileId] ?? 0) + UInt64(data.count)
                    try? fileHandle.close()
                } catch {
                    try? fileHandle.close()
                    throw NSError(domain: "FileErrorDomain", code: 1006,
                                  userInfo: [NSLocalizedDescriptionKey: "Error writing to file: \(error.localizedDescription)"])
                }
            }
        }
        try result.get()
    }
    /// Rotates the log file
    /// - Parameters:
    ///   - fileURL: Current log file URL
    ///   - maxBackupCount: Max backup files
    private static func rotateLogFile(_ fileURL: URL, maxBackupCount: Int) {
        let fileManager = FileManager.default
        let path = fileURL.path
        
        do {
            // Remove the oldest backup if at max
            if maxBackupCount > 0 {
                let oldestBackupPath = path + ".\(maxBackupCount)"
                if fileManager.fileExists(atPath: oldestBackupPath) {
                    try fileManager.removeItem(atPath: oldestBackupPath)
                }
            }
            
            // Shift existing backups
            for i in stride(from: maxBackupCount - 1, through: 1, by: -1) {
                let currentBackupPath = path + ".\(i)"
                let newBackupPath = path + ".\(i + 1)"
                
                if fileManager.fileExists(atPath: currentBackupPath) {
                    try fileManager.moveItem(atPath: currentBackupPath, toPath: newBackupPath)
                }
            }
            
            // Move current log to .1
            if fileManager.fileExists(atPath: path) {
                try fileManager.moveItem(atPath: path, toPath: path + ".1")
            }
        } catch {
#if DEBUG
            print("Error rotating log files: \(error)")
#endif
        }
    }
}
