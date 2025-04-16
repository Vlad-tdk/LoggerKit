//
//  OSLogAdapter.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation
import os.log
/// Adapter for integration with OSLog (Apple Instruments)
public class OSLogAdapter: LogAdapter {
    private let osLog: OSLog
    
    /// Initializes a new OSLog adapter
    /// - Parameters:
    ///   - subsystem: Subsystem identifier
    ///   - category: Category
    public init(subsystem: String, category: String) {
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    /// Performs logging through OSLog
    /// - Parameters:
    ///   - message: Message
    ///   - level: Logging level
    ///   - subsystem: Subsystem
    ///   - category: Category
    ///   - file: File
    ///   - function: Function
    ///   - line: Line number
    public func log(message: String, level: Level, subsystem: String, category: String, file: String, function: String, line: Int) {
        let osLogType = mapLogLevel(level)
        os_log("%{public}@", log: osLog, type: osLogType, message)
    }
    
    /// Converts Logger log level to OSLogType
    /// - Parameter level: Logger log level
    /// - Returns: Corresponding OSLogType
    private func mapLogLevel(_ level: Level) -> OSLogType {
        switch level {
        case .debug:    return .debug
        case .info:     return .info
        case .warning:  return .default
        case .error:    return .error
        case .critical: return .fault
        }
    }
}


// MARK: - Example usage

/*
 // Registering adapters (done once in the application)
 Logger.addAdapter(OSLogAdapter(subsystem: "com.myapp", category: "System"))
 
 // Implementation of the LogosLogging protocol
 class MyLogosLogger: LogosAdapter.LogosLogging {
 func logMessage(_ message: String, level: Int, source: String) {
 print("LOGOS: [\(source)] [\(level)] \(message)")
 }
 }
 
 // Adding Logos adapter
 let myLogosLogger = MyLogosLogger()
 Logger.addAdapter(LogosAdapter(logosLogger: myLogosLogger, source: "AppModule"))
 
 // Creating a logger for a component
 let logger = Logger(
 subsystem: "com.myapp",
 category: "Network",
 minLevel: .info,
 writeToFile: true
 )
 
 // Using the logger
 logger.info("Request started")
 logger.warning("Slow response")
 logger.error("Connection error")
 */
