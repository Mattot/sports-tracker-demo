import os

/// Central `os.Logger` namespace for the app's subsystems.
public enum Loggers {
    private static let subsystem = "com.matusselecky.sportstracker"

    public static let connectivity = Logger(subsystem: subsystem, category: "connectivity")
}
