import QtQuick

// Plasma's C++ enums. QML-declared enums are the only way to expose
// `PlasmaCore.Types.NeedsAttentionStatus` from a stub — a property cannot
// start with a capital letter.
QtObject {
    enum ItemStatus {
        UnknownStatus,
        PassiveStatus,
        ActiveStatus,
        NeedsAttentionStatus,
        RequiresAttentionStatus,
        AcceptingInputStatus,
        HiddenStatus
    }

    enum FormFactor {
        Planar,
        MediaCenter,
        Horizontal,
        Vertical,
        Application
    }

    enum BackgroundHints {
        NoBackground,
        StandardBackground,
        TranslucentBackground,
        ShadowBackground,
        ConfigurableBackground,
        DefaultBackground
    }
}
