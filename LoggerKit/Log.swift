//
//  Log.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation

/// Centralized access to application loggers
public enum Log {
    // MARK: - General Logging Configuration
    
    /// Root app identifier used for all subsystems
    private static let appIdentifier = Bundle.main.bundleIdentifier ?? "com.app"
    
    /// Directory for storing log files
    private static let logsDirectory: URL = {
        let baseDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return baseDir.appendingPathComponent("Logs", isDirectory: true)
    }()
    
    /// Default minimum log level
    private static let defaultMinLevel: Level = .info
    
    /// Default maximum log file size (5 MB)
    private static let defaultMaxFileSize: UInt64 = 5 * 1024 * 1024
    
    /// Default number of log file backups
    private static let defaultBackupCount: Int = 3
    
    // MARK: - Available Loggers
    
    /// Logger for system events
    public static let system = Logger(
        subsystem: appIdentifier,
        category: "System",
        minLevel: defaultMinLevel,
        writeToFile: true,
        directory: logsDirectory,
        filename: "system.log",
        maxFileSize: defaultMaxFileSize,
        maxBackupCount: defaultBackupCount,
        style: .emoji
    )
    
    /// Logger for database events
    public static let db = Logger(
        subsystem: appIdentifier,
        category: "Database",
        minLevel: .warning,  // Only warnings and errors
        writeToFile: true,
        directory: logsDirectory,
        filename: "database.log",
        maxFileSize: defaultMaxFileSize,
        maxBackupCount: defaultBackupCount,
        style: .plain
    )
    
    /// Logger for network operations
    public static let network = Logger(
        subsystem: appIdentifier,
        category: "Network",
        minLevel: .info,
        writeToFile: true,
        directory: logsDirectory,
        filename: "network.log",
        maxFileSize: defaultMaxFileSize,
        maxBackupCount: defaultBackupCount,
        style: .colorCode,
        destinations: .all
    )
    
    /// Logger for UI events
    public static let ui = Logger(
        subsystem: appIdentifier,
        category: "UI",
        minLevel: .debug,
        writeToFile: false,   // UI logs are usually not written to a file
        style: .emoji,
        destinations: .consoleAndAdapters
    )
    
    /// Logger for debugging
    public static let debug = Logger(
        subsystem: appIdentifier,
        category: "Debug",
        minLevel: .debug,
        writeToFile: true,
        directory: logsDirectory,
        filename: "debug.log",
        maxFileSize: defaultMaxFileSize,
        maxBackupCount: 1,  // Fewer backups for debug logs
        style: .plain
    )
    
    // MARK: - Adapter Initialization
    
    /// Initializes all logging adapters
    public static func initializeAdapters() {
#if DEBUG
        // In debug mode, initialize OSLog
        let osLogAdapter = OSLogAdapter(subsystem: appIdentifier, category: "App")
        Logger.addAdapter(osLogAdapter)
        
        // Example of initializing the Logos adapter, if used
        // let logosLogger = CustomLogosLogger()
        // let logosAdapter = LogosAdapter(logosLogger: logosLogger, source: "AppModule")
        // Logger.addAdapter(logosAdapter)
        
        system.info("Logging adapters initialized")
#endif
    }
    
    // MARK: - Utility Methods
    
    /// Returns URLs for all log files
    public static var allLogFiles: [URL] {
        do {
            let fileManager = FileManager.default
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: logsDirectory.path) {
                try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
                return []
            }
            
            // Get all files in log directory
            let files = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil)
            
            // Filter only .log files
            return files.filter { $0.pathExtension == "log" }
        } catch {
            system.error("Error getting list of log files: \(error)")
            return []
        }
    }
    
    /// Clears all log files
    public static func clearAllLogs() {
        do {
            let fileManager = FileManager.default
            
            // Get all log files
            let logFiles = allLogFiles
            
            // Remove each file
            for file in logFiles {
                try fileManager.removeItem(at: file)
            }
            
            system.info("All log files deleted")
        } catch {
            system.error("Error clearing log files: \(error)")
        }
    }
    public static var logDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let logDir = paths[0].appendingPathComponent("Logs", isDirectory: true)
        
        // Создаем директорию при первом доступе
        if !FileManager.default.fileExists(atPath: logDir.path) {
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        }
        
        return logDir
    }
}

// MARK: - Example Usage

/*
 // At the start of the application, initialize adapters
 func applicationDidFinishLaunching() {
 Log.initializeAdapters()
 
 // Now loggers can be used anywhere in the application
 Log.system.info("Application started")
 Log.network.debug("Setting up network layer")
 Log.db.warning("Slow database query")
 }
 
 // In other parts of the application
 func someNetworkCall() {
 Log.network.info("Making API request")
 // ...
 Log.network.error("Failed to connect to server")
 }
 
 func databaseOperation() {
 Log.db.info("Requesting data from database")
 // ...
 }
 
 func userInterfaceAction() {
 Log.ui.debug("User pressed button")
 // ...
 }
 */
