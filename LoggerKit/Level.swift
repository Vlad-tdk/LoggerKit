//
//  Level.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation

// MARK: - Logging Levels

public enum Level: Int, Comparable {
    case debug = 0    // Debug information
    case info = 1     // Informational messages
    case warning = 2  // Warnings
    case error = 3    // Errors
    case critical = 4 // Critical
    public static func < (lhs: Level, rhs: Level) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
