# 📝 Logger.swift – Lightweight Logging Framework for Swift

`Logger` is a powerful yet simple and extensible logger designed for Swift applications. It supports output to the console, log files, and external adapters (such as OSLog and Logos).

## 🔧 Key Features

- ✅ Supports multiple log levels: `debug`, `info`, `warning`, `error`, `critical`
- ✅ Flexible log styles:
  - `.plain` — plain text (e.g., `[ERROR]`)
  - `.emoji` — with emoji (e.g., `[❌ ERROR]`)
  - `.colorCode` — ANSI color codes for terminal output (⚠️ **console-only**)
  - `.custom` — custom formatting function
- ✅ Output targets:
  - Console
  - Log file with rotation and backups
  - External adapters (`OSLog`, `Logos`, etc.)
- ✅ Thread-safe logging queue
- ✅ Centralized access via `Log.system`, `Log.db`, etc.

## 📦 Initialization Example

```swift
let logger = Logger(
    subsystem: "com.example.app",
    category: "Network",
    minLevel: .debug,
    writeToFile: true,
    style: .emoji
)
```

## 🖨 Usage

```swift
logger.debug("Debug message")
logger.info("Information")
logger.warning("Warning")
logger.error("Error occurred")
logger.critical("Critical failure")
```

## 🎨 Log Styles (`LogStyle`)

| Style         | Example Output                  | Use Case                            |
|---------------|----------------------------------|--------------------------------------|
| `.plain`      | `[ERROR]`                        | UI, log files                        |
| `.emoji`      | `[❌ ERROR]`                      | UI, log files                        |
| `.colorCode`  | `\u{001B}[31mERROR\u{001B}[0m`    | Console only (Terminal)              |
| `.custom`     | `[E]`, `[INFO!]`, etc.           | Full control over format             |

### Custom Style Example

```swift
let logger = Logger(
    subsystem: "com.app",
    category: "Security",
    style: .custom { level in
        switch level {
        case .debug: return "[D]"
        case .info: return "[I]"
        case .warning: return "[W]"
        case .error: return "[E]"
        case .critical: return "[CRIT]"
        }
    }
)
```

## 📁 Log File Management

- Log files are saved to `Documents/Logs`
- Default max size: 1 MB
- Supports rotation and up to 5 backups (`.log.1`, `.log.2`, ...)

## 🧰 Centralized Loggers

```swift
Log.system.info("System initialized")
Log.network.error("Network error")
Log.db.warning("Slow query")
Log.ui.debug("Button tapped")
```

## 🔌 Log Adapters

Integration with external systems:

- ✅ `OSLogAdapter` — for output to Console.app and Xcode Instruments
- ✅ `LogosAdapter` — for integration with internal logging systems conforming to the `LogosLogging` protocol (used in large-scale or enterprise projects)

### Example: Adding Adapters

```swift
Logger.addAdapter(OSLogAdapter(subsystem: "com.app", category: "System"))
Logger.addAdapter(LogosAdapter(logosLogger: CustomLogosImpl(), source: "Analytics"))
```

## 👀 LogViewerView

A SwiftUI component for viewing logs inside the app:

```swift
.sheet(isPresented: $showLogs) {
    LogViewerView()
}
```

- File selection
- Search and filter by level
- Auto-refresh
- Delete / clear logs
- Export via `UIActivityViewController`

## ⚠️ Important Notes

- `LogStyle.colorCode` is intended **for terminal output only**. It may produce unreadable escape codes in log files or UI.
- For UI and file output, use `.plain` or `.emoji`.

## 🚧 In Progress

### ☁️ Log Archiving and Uploading

Via `LogUploaderService`:

- Prepares `.zip` archive
- Upload to server
- Supports custom headers, deviceInfo
- Share sheet integration

### 📌 TODO

- [ ] Split logs by date
- [ ] Daily log archive
- [ ] Web interface for log browsing

## 👨‍🔬 For Testers and QA

This logger is also a great companion for testers and QA engineers. It helps capture detailed runtime information, making it easier to reproduce and debug issues. Clear log formatting, in-app log viewer, and export functionality empower QA teams to report high-quality, actionable bug reports.
