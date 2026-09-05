import QtQuick

// Kirigami's message severities are a C++ enum; a QML-declared enum is the
// only way to expose `Kirigami.MessageType.Positive` from a stub.
QtObject {
    enum Type {
        Information,
        Positive,
        Warning,
        Error
    }
}
