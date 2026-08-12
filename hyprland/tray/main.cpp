// Gitpulse tray helper for Hyprland.
//
// Quickshell has no system-tray item of its own, so this tiny Qt Widgets
// binary owns the StatusNotifier entry and drives the shell over
// `qs ipc -p <config> call panel <method>`.
//
// It deliberately holds no GitHub logic: the badge count and tooltip are asked
// of the running shell, which already has the data, rather than re-fetched
// here with a second copy of the token.

#include <QAction>
#include <QApplication>
#include <QColor>
#include <QIcon>
#include <QMenu>
#include <QPainter>
#include <QPixmap>
#include <QProcess>
#include <QString>
#include <QSvgRenderer>
#include <QSystemTrayIcon>
#include <QTimer>

namespace {

/// Renders the same org.muddyblack.gitpulse.svg the Plasma package installs,
/// so the Hyprland tray icon is the actual mark rather than a hand-drawn
/// stand-in for it.
QIcon renderIcon(const QString &iconPath, const QString &badge)
{
    QPixmap pixmap(64, 64);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);

    QSvgRenderer renderer(iconPath);
    if (renderer.isValid())
        renderer.render(&painter, QRectF(4, 4, 56, 56));

    if (!badge.isEmpty() && badge != QLatin1String("0")) {
        // Same rule as the plasmoid: the badge only ever shows "needs you".
        painter.setPen(Qt::NoPen);
        painter.setBrush(QColor("#da4453"));
        const QRectF bubble(34, 2, 28, 28);
        painter.drawEllipse(bubble);

        QFont font = painter.font();
        font.setPixelSize(badge.size() > 1 ? 15 : 19);
        font.setBold(true);
        painter.setFont(font);
        painter.setPen(QColor("#ffffff"));
        painter.drawText(bubble, Qt::AlignCenter, badge);
    }

    painter.end();
    return QIcon(pixmap);
}

} // namespace

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Gitpulse"));
    app.setQuitOnLastWindowClosed(false);

    if (argc != 4) {
        qWarning("usage: gitpulse-tray <path-to-qs> <path-to-shell.qml> <path-to-icon.svg>");
        return 2;
    }

    const QString qsPath = QString::fromLocal8Bit(argv[1]);
    const QString configPath = QString::fromLocal8Bit(argv[2]);
    const QString iconPath = QString::fromLocal8Bit(argv[3]);

    const auto call = [&](const QString &method) {
        QProcess::startDetached(qsPath, {"ipc", "-p", configPath, "call", "panel", method});
    };

    /// Synchronous because the answer is needed to paint; the shell replies in
    /// single-digit milliseconds and a stale tray icon is worse than a blip.
    const auto ask = [&](const QString &method) -> QString {
        QProcess process;
        process.start(qsPath, {"ipc", "-p", configPath, "call", "panel", method});
        if (!process.waitForFinished(2000))
            return QString();
        return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    };

    QSystemTrayIcon tray{renderIcon(iconPath, QString())};
    tray.setToolTip(QStringLiteral("Gitpulse"));

    QString lastBadge;
    const auto sync = [&] {
        const QString badge = ask(QStringLiteral("badge"));
        if (badge != lastBadge) {
            lastBadge = badge;
            tray.setIcon(renderIcon(iconPath, badge));
        }
        const QString summary = ask(QStringLiteral("summary"));
        tray.setToolTip(summary.isEmpty() ? QStringLiteral("Gitpulse") : summary);
    };

    QTimer poll;
    poll.setInterval(30000);
    QObject::connect(&poll, &QTimer::timeout, sync);
    poll.start();
    // The shell needs a moment to come up before it can answer.
    QTimer::singleShot(2000, sync);

    QMenu menu;
    QAction *openAction = menu.addAction(QStringLiteral("Open Gitpulse"));
    QAction *refreshAction = menu.addAction(QStringLiteral("Refresh"));
    menu.addSeparator();
    QAction *quitAction = menu.addAction(QStringLiteral("Quit Gitpulse"));

    QObject::connect(openAction, &QAction::triggered, [&] { call(QStringLiteral("toggle")); });
    QObject::connect(refreshAction, &QAction::triggered, [&] {
        call(QStringLiteral("refresh"));
        QTimer::singleShot(1500, sync);
    });
    QObject::connect(quitAction, &QAction::triggered, [&] {
        call(QStringLiteral("quit"));
        QTimer::singleShot(300, &app, &QApplication::quit);
    });

    tray.setContextMenu(&menu);
    QObject::connect(&tray, &QSystemTrayIcon::activated, [&](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick)
            call(QStringLiteral("toggle"));
        else if (reason == QSystemTrayIcon::MiddleClick)
            call(QStringLiteral("refresh"));
    });

    tray.show();
    return app.exec();
}
