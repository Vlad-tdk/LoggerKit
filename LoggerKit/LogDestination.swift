//
//  LogDestination.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation

// MARK: - Log Destinations

public struct LogDestination: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let console = LogDestination(rawValue: 1 << 0)  // Output to console
    public static let file = LogDestination(rawValue: 1 << 1)     // Write to file
    public static let adapters = LogDestination(rawValue: 1 << 2) // Send to adapters
    
    public static let all: LogDestination = [.console, .file, .adapters]
    public static let consoleAndFile: LogDestination = [.console, .file]
    public static let consoleAndAdapters: LogDestination = [.console, .adapters]
    public static let fileAndAdapters: LogDestination = [.file, .adapters]
    
}
