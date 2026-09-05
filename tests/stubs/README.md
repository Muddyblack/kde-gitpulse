# Plasma stand-ins for the offscreen test run

Just enough of Kirigami, PlasmaComponents, PlasmaExtras and the plasmoid API
for `tests/plasma-smoke.qml` to render `PopupView.qml` and `PanelSlot.qml` —
the real files, unmodified — on a machine with no Plasma installed, which is
what CI and most contributors' containers are.

These are **not** a Plasma implementation. They exist to catch the class of bug
qmllint cannot see: a binding that throws, a property that does not exist, a
layout that collapses. Anything that depends on Plasma's actual look (theme
colours, icon theme, dialog chrome) is approximated, so a screenshot from here
shows structure and behaviour rather than pixel-accurate Plasma styling.

The config pages are deliberately out of scope: `Kirigami.FormData` is an
attached property, which cannot be written in QML, and stubbing it would say
more about the stub than about the widget.
