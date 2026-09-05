// KLocalizedContext's globals, for a run without Plasma.
//
// `i18n()` and friends are not QML — they are functions Plasma installs on the
// JavaScript global object through KLocalizedContext. Outside a Plasma session
// they simply do not exist, and every one of the widget's several hundred
// calls is a ReferenceError.
//
// Reaching the global object from QML needs the Function constructor: QV4
// refuses a bare assignment to an undeclared name ("Invalid write to global
// property"), so `Function("return this")()` is the portable way in. This
// keeps the stub inside QML, which means the smoke test runs under the real
// `qml` tool and not only under a bespoke harness.
.pragma library

/** "%1 of %2" with the arguments substituted, the way KLocalizedString does. */
function _format(text, args) {
    return String(text).replace(/%(\d)/g, function (whole, index) {
        var v = args[Number(index) - 1];
        return v === undefined ? whole : String(v);
    });
}

function install() {
    var global = Function("return this")();
    if (global.i18n)
        return;

    global.i18n = function (text) {
        return _format(text, Array.prototype.slice.call(arguments, 1));
    };

    // The context argument is a hint for translators; it never reaches the UI.
    global.i18nc = function (context, text) {
        return _format(text, Array.prototype.slice.call(arguments, 2));
    };

    global.i18np = function (singular, plural, n) {
        var rest = Array.prototype.slice.call(arguments, 2);
        return _format(n === 1 ? singular : plural, rest);
    };

    global.i18ncp = function (context, singular, plural, n) {
        var rest = Array.prototype.slice.call(arguments, 3);
        return _format(n === 1 ? singular : plural, rest);
    };

    // The xi18n* family takes the same arguments and adds markup this stub has
    // no reason to render.
    global.xi18n = global.i18n;
    global.xi18nc = global.i18nc;
    global.xi18np = global.i18np;
    global.xi18ncp = global.i18ncp;
}
