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
    
    /// Minimum log level based on build configuration
    private static let defaultMinLevel: Level = {
#if DEBUG
        return .debug  // В debug режиме логируем всё
#else
        return .error  // В релизе только error и critical
#endif
    }()
    
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
        minLevel: {
#if DEBUG
            return .warning  // В debug показываем предупреждения
#else
            return .error    // В релизе только ошибки
#endif
        }(),
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
        minLevel: defaultMinLevel,
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
        minLevel: {
#if DEBUG
            return .debug    // В debug режиме логируем UI события
#else
            return .critical // В релизе только критичные UI проблемы
#endif
        }(),
        writeToFile: {
#if DEBUG
            return false     // UI логи в debug не записываем в файл
#else
            return true      // В релизе записываем критичные проблемы
#endif
        }(),
        style: .emoji,
        destinations: {
#if DEBUG
            return .consoleAndAdapters
#else
            return .fileAndAdapters  // В релизе только в файл и адаптеры
#endif
        }()
    )
    
    /// Logger for debugging
    public static let debug = Logger(
        subsystem: appIdentifier,
        category: "Debug",
        minLevel: {
#if DEBUG
            return .debug
#else
            return .critical  // В релизе debug логгер практически отключен
#endif
        }(),
        writeToFile: {
#if DEBUG
            return true
#else
            return false      // В релизе debug логи не записываем
#endif
        }(),
        directory: logsDirectory,
        filename: "debug.log",
        maxFileSize: defaultMaxFileSize,
        maxBackupCount: 1,
        style: .plain
    )
    
    // MARK: - Adapter Initialization
    
    /// Initializes all logging adapters
    public static func initializeAdapters() {
#if DEBUG
        // В debug режиме инициализируем OSLog
        let osLogAdapter = OSLogAdapter(subsystem: appIdentifier, category: "App")
        Logger.addAdapter(osLogAdapter)
        
        system.info("Logging adapters initialized (DEBUG)")
#else
        // В релизе тоже можем использовать OSLog для критичных событий
        let osLogAdapter = OSLogAdapter(subsystem: appIdentifier, category: "App")
        Logger.addAdapter(osLogAdapter)
        
        system.error("Logging adapters initialized (RELEASE)")
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
 
 // В debug режиме будут логироваться все сообщения
 // В release режиме только error и critical
 Log.system.info("Application started")      // Только в DEBUG
 Log.network.debug("Setting up network")     // Только в DEBUG
 Log.db.warning("Slow database query")       // Только в DEBUG
 Log.system.error("Critical system error")   // В DEBUG и RELEASE
 }
 */
