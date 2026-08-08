// A tintable vector glyph.
//
// QtQuick.Shapes ships with qtdeclarative, so this needs no icon theme, no
// image files and no extra QML module — which is the whole point on a desktop
// where Kirigami may not be installed.
import QtQuick
import QtQuick.Shapes

import "Icons.js" as Glyphs

Item {
    id: icon

    property string name: ""
    property color color: "#ffffff"
    /** Set true for in-progress runs; spins at the shell's long duration. */
    property bool spinning: false

    readonly property var glyph: Glyphs.GLYPHS[icon.name] || null

    implicitWidth: 16
    implicitHeight: 16

    Shape {
        id: shape

        anchors.centerIn: parent
        width: 16
        height: 16
        // Authored at 16×16 and scaled, so one path table serves every size.
        scale: Math.min(icon.width, icon.height) / 16
        antialiasing: true
        visible: icon.glyph !== null

        ShapePath {
            fillColor: icon.glyph && icon.glyph.fill ? icon.color : "transparent"
            strokeColor: icon.glyph && icon.glyph.stroke ? icon.color : "transparent"
            strokeWidth: icon.glyph && icon.glyph.w ? icon.glyph.w : 0
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            // SVG's default is nonzero winding; Shapes defaults to odd-even,
            // which punches holes in glyphs that were not drawn for it.
            fillRule: ShapePath.WindingFill

            PathSvg {
                path: icon.glyph ? (icon.glyph.fill || icon.glyph.stroke || "") : ""
            }
        }

        // Second pass for glyphs that mix a stroked body with filled details
        // (the gear's spokes, the merge nodes, the alert's dot).
        ShapePath {
            fillColor: icon.glyph && icon.glyph.extra && !icon.glyph.extraW ? icon.color : "transparent"
            strokeColor: icon.glyph && icon.glyph.extraW ? icon.color : "transparent"
            strokeWidth: icon.glyph && icon.glyph.extraW ? icon.glyph.extraW : 0
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillRule: ShapePath.WindingFill

            PathSvg {
                path: icon.glyph && icon.glyph.extra ? icon.glyph.extra : ""
            }
        }

        RotationAnimator on rotation {
            running: icon.spinning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1400
        }
    }
}
