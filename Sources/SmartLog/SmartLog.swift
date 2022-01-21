import Darwin
import Foundation
import Logging

let _smartSystemStderr = Darwin.stderr
let _smartSystemStdout = Darwin.stdout

internal struct SmartStdioOutputStream: TextOutputStream {
  internal let file: UnsafeMutablePointer<FILE>
  internal let flushMode: FlushMode

  internal func write(_ string: String) {
    string.withCString { ptr in
      flockfile(self.file)
      defer {
        funlockfile(self.file)
      }
      _ = fputs(ptr, self.file)
      if case .always = self.flushMode {
        self.flush()
      }
    }
  }

  internal func flush() {
    _ = fflush(file)
  }

  internal static let stderr = SmartStdioOutputStream(file: _smartSystemStderr, flushMode: .always)
  internal static let stdout = SmartStdioOutputStream(file: _smartSystemStdout, flushMode: .always)

  internal enum FlushMode {
    case undefined
    case always
  }
}

struct SmartLoggingBase {
  static let shared = SmartLoggingBase()

  let startTime = CFAbsoluteTimeGetCurrent()
}

public struct SmartStreamLogHandler: LogHandler {
  public static func standardOutput(label: String) -> SmartStreamLogHandler {
    return SmartStreamLogHandler(label: label, stream: SmartStdioOutputStream.stdout)
  }

  public static func standardError(label: String) -> SmartStreamLogHandler {
    return SmartStreamLogHandler(label: label, stream: SmartStdioOutputStream.stderr)
  }

  private let stream: TextOutputStream
  private let label: String
  private let colors: Bool = true
  private let startTime = CFAbsoluteTimeGetCurrent()

  public var logLevel: Logger.Level = .trace
  private var prettyMetadata: String?

  public var metadata = Logger.Metadata() {
    didSet {
      prettyMetadata = prettify(metadata)
    }
  }

  public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
    get {
      return metadata[metadataKey]
    }
    set {
      metadata[metadataKey] = newValue
    }
  }

  // internal for testing only
  internal init(label: String, stream: TextOutputStream, level: Logger.Level = .trace) {
    self.label = label
    self.stream = stream
    logLevel = level
  }

  public func log(level: Logger.Level,
                  message: Logger.Message,
                  metadata: Logger.Metadata?,
                  source: String,
                  file: String,
                  function: String,
                  line: UInt) {
    let prettyMetadata = metadata?.isEmpty ?? true
      ? self.prettyMetadata
      : prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))

    var stream = self.stream

    var prefix: String
    if colors {
      switch level {
      case .error:
        prefix = "🛑 E|*** "
      case .warning:
        prefix = "🔶 W|**  "
      case .info:
        prefix = "🔷 I|*   "
      case .debug:
        prefix = "◾️ D|    "
      default:
        prefix = "◽️ X|    "
      }
    } else {
      switch level {
      case .error:
        prefix = "E|*** "
      case .warning:
        prefix = "W|**  "
      case .info:
        prefix = "I|*   "
      case .debug:
        prefix = "D|    "
      default:
        prefix = "X|    "
      }
    }

    let mainThread = Thread.isMainThread ? "◽️" : "🚀"

    let label = self.label.count > 0 ? "[\(self.label)] " : ""

    let fileName = URL(fileURLWithPath: file).lastPathComponent

    let now = CFAbsoluteTimeGetCurrent()
    let elapsed = now - SmartLoggingBase.shared.startTime
    let time: String = String(format: "%.3f", elapsed)

    stream.write("\(mainThread) \(prefix) \(time) \(label)<\(fileName):\(line)>  \(prettyMetadata.map { " \($0)" } ?? "") \(message)\n")
  }

  private func prettify(_ metadata: Logger.Metadata) -> String? {
    return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
  }

  private func timestamp() -> String {
    var buffer = [Int8](repeating: 0, count: 255)
    var timestamp = time(nil)
    let localTime = localtime(&timestamp)
    strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
    return buffer.withUnsafeBufferPointer {
      $0.withMemoryRebound(to: CChar.self) {
        String(cString: $0.baseAddress!)
      }
    }
  }
}

public func useSmartLog(_ additionalHandlers: [LogHandler] = [], exclusive: Bool = false) {
  _ = SmartLoggingBase.shared
  LoggingSystem.bootstrap { label in
    if exclusive {
      return MultiplexLogHandler(additionalHandlers)  
    }
    var handlers: [LogHandler] = [
      // FileLogHandler(label: label, fileLogger: fileLogger),
      SmartStreamLogHandler.standardOutput(label: label),
    ]
    handlers.append(contentsOf: additionalHandlers)
    return MultiplexLogHandler(handlers)
  }
}

var hasLogger = false

public func SmartLogger(label: String? = nil, file: String = #file) -> Logger {
  var logger: Logger?
  if label == nil {
    let utf8All = file.utf8
    let module = file.utf8.lastIndex(of: UInt8(ascii: "/")).flatMap { lastSlash -> Substring? in
      utf8All[..<lastSlash].lastIndex(of: UInt8(ascii: "/")).map { secondLastSlash -> Substring in
        file[utf8All.index(after: secondLastSlash) ..< lastSlash]
      }
    }.map {
      String($0)
    }
    logger = Logger(label: module ?? "")
  }
  if logger == nil {
    logger = Logger(label: label ?? "")
  }

  if !hasLogger {
    logger?.info("Logger started \(Bundle.main.release)")
    hasLogger = true
  }

  return logger!
}

extension Bundle {
  public var release: String {
    let id = Bundle.main.infoDictionary?["CFBundleIdentifier"] ?? ""
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""
    return "\(id)@\(version)+\(build)"
  }
}
