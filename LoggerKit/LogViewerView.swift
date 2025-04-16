//
//   LogViewerView.swift
//   LoggerKit
//
//   Created by Vladimir Martemianov on 16.4.25.
//

import SwiftUI

/// SwiftUI component for viewing log file contents directly in the application
public struct LogViewerView: View {
    // MARK: - Properties
    
    /// List of available log files
    @State var logFiles: [URL] = []
    
    /// Selected log file
    @State var selectedLogFile: URL?
    
    /// Content of the selected log file
    @State var logContent: String = ""
    
    /// Loading indicator
    @State var isLoading: Bool = false
    
    /// Error message
    @State var errorMessage: String?
    
    /// Search text for logs
    @State var searchText: String = ""
    
    /// Minimum logging level to display
    @State var filterLevel: Level? = nil
    
    /// Automatic log updates
    @State var autoRefresh: Bool = false
    
    /// Timer for auto-refresh
    @State var timer: Timer?
    
    /// Auto-refresh interval in seconds
    @State var refreshInterval: TimeInterval = 5.0
    
    /// Focus state for the search field
    @FocusState var isSearchFieldFocused: Bool
    
    // MARK: - Initialization and Deinitialization
    
    public init() {
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: 12) {
                    // Log file selector
                    logFileSelector
                    
                    // Search field with improved design
                    searchField
                    
                    // Log level filter
                    logLevelFilter
                    
                    // Log content with improved design
                    logContentView
                    
                    // Improved toolbar
                    toolbarView
                }
                .padding(.vertical)
            }
            .navigationTitle("Log Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        shareLogFile()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(selectedLogFile == nil)
                }
            }
        }
        .onAppear {
            loadLogFiles()
        }
        .onDisappear {
            // Stop timer when screen closes
            timer?.invalidate()
            timer = nil
        }
        .onTapGesture {
            // Additional check to hide keyboard when tapping anywhere
            hideKeyboard()
        }
    }
    
    // MARK: - UI Components
    
    private var logFileSelector: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            
            Picker("", selection: $selectedLogFile) {
                ForEach(logFiles, id: \.self) { file in
                    Text(file.lastPathComponent).tag(file as URL?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedLogFile) { _, _ in
                loadLogContent()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search in log", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    hideKeyboard()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var logLevelFilter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Logging Level:")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Picker("", selection: $filterLevel) {
                Text("All").tag(nil as Level?)
                Text("Debug").tag(Level.debug as Level?)
                Text("Info").tag(Level.info as Level?)
                Text("Warning").tag(Level.warning as Level?)
                Text("Error").tag(Level.error as Level?)
                Text("Critical").tag(Level.critical as Level?)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: filterLevel) {_, _ in
                hideKeyboard()
            }
        }
        .padding(.horizontal)
    }
    
    private var logContentView: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(filteredLogContent.split(separator: "\n").enumerated()), id: \.offset) { index, line in
                                let lineText = String(line)
                                Text(lineText)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(colorForLogLine(lineText))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 1)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        hideKeyboard()
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color(UIColor.systemBackground))
                    .onTapGesture {
                        hideKeyboard()
                    }
                    .onChange(of: logContent) {_, _ in
                        // Scroll to the last line when content updates
                        if !logContent.isEmpty {
                            let lines = logContent.split(separator: "\n")
                            if !lines.isEmpty {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        scrollView.scrollTo(lines.count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Refresh button
            Button(action: loadLogContent) {
                VStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                    Text("Refresh")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Spacer()
            
            // Auto-refresh toggle
            VStack {
                Toggle("", isOn: $autoRefresh)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                Text("Auto-refresh")
                    .font(.caption)
            }
            .onChange(of: autoRefresh) {_, _ in
                toggleAutoRefresh()
            }
            
            Spacer()
            
            // Clear button
            Button(action: clearDisplayedLog) {
                VStack {
                    Image(systemName: "clear")
                        .font(.system(size: 18))
                    Text("Clear")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(selectedLogFile == nil)
            
            // Delete button
            Button(action: deleteSelectedLog) {
                VStack {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                    Text("Delete")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .foregroundColor(.red)
            .disabled(selectedLogFile == nil)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}
