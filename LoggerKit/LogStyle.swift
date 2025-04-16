//
//  LogStyle.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation

// MARK: - Log Style

public enum LogStyle {
    case plain                      // Plain text
    case emoji                      // Emoji for levels
    case colorCode                  // ANSI color codes (for terminals)
    case custom((Level) -> String)  // Custom formatter
    
    func apply(to level: Level) -> String {
        switch self {
        case .plain:
            switch level {
            case .debug:    return "DEBUG"
            case .info:     return "INFO"
            case .warning:  return "WARNING"
            case .error:    return "ERROR"
            case .critical: return "CRITICAL"
            }
        case .emoji:
            switch level {
            case .debug:    return "🔍 DEBUG"
            case .info:     return "ℹ️ INFO"
            case .warning:  return "⚠️ WARNING"
            case .error:    return "❌ ERROR"
            case .critical: return "🔥 CRITICAL"
            }
        case .colorCode:
            switch level {
            case .debug:    return "\u{001B}[37mDEBUG\u{001B}[0m"     // White
            case .info:     return "\u{001B}[34mINFO\u{001B}[0m"      // Blue
            case .warning:  return "\u{001B}[33mWARNING\u{001B}[0m"   // Yellow
            case .error:    return "\u{001B}[31mERROR\u{001B}[0m"     // Red
            case .critical: return "\u{001B}[35mCRITICAL\u{001B}[0m"  // Purple
            }
        case .custom(let formatter):
            return formatter(level)
        }
    }
}
