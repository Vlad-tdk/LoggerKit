//
//  LogosAdapter.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation

/// Adapter for integration with the Logos logging system
public class LogosAdapter: LogAdapter {
    /// Internal protocol for Logos logging
    public protocol LogosLogging {
        func logMessage(_ message: String, level: Int, source: String)
    }
    
    private let logosLogger: LogosLogging
    private let source: String
    
    /// Initializes a new Logos adapter
    /// - Parameters:
    ///   - logosLogger: Logger instance conforming to LogosLogging protocol
    ///   - source: Log source identifier
    public init(logosLogger: LogosLogging, source: String) {
        self.logosLogger = logosLogger
        self.source = source
    }
    
    /// Performs logging through Logos
    /// - Parameters:
    ///   - message: Message
    ///   - level: Logging level
    ///   - subsystem: Subsystem
    ///   - category: Category
    ///   - file: File
    ///   - function: Function
    ///   - line: Line number
    public func log(message: String, level: Level, subsystem: String, category: String, file: String, function: String, line: Int) {
        logosLogger.logMessage(message, level: level.rawValue, source: source)
    }
}
