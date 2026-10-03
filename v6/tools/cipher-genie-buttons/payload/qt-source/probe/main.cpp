#include <cstdio>
#include <QApplication>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
#include <QPluginLoader>
#include <QTextStream>
#include <QTimer>
#include <QVBoxLayout>
#include <QWidget>

int main(int argc, char **argv)
{
        if (QString::fromLatin1(qVersion()) != QString::fromLatin1(QT_VERSION_STR)) {
            QTextStream(stderr) << "Qt headers/runtime version mismatch\n";
            return 1;
        }

    if (argc == 2 && QString::fromLocal8Bit(argv[1]) == "--version") {
        QCoreApplication app(argc, argv);
        QTextStream(stdout) << qVersion() << '\n';
        return 0;
    }
    if (argc == 3 && QString::fromLocal8Bit(argv[1]) == "--verify-plugin") {
        QCoreApplication app(argc, argv);
        QPluginLoader loader(QString::fromLocal8Bit(argv[2]));
        const auto keys = loader.metaData().value("MetaData").toObject().value("Keys").toArray();
        if (!keys.contains(QString("whitesur-gtk")) || !loader.load()) {
            QTextStream(stderr) << "Decoration plugin rejected: " << loader.errorString() << '\n';
            return 1;
        }
        QTextStream(stdout) << "Plugin loaded with Qt " << qVersion() << '\n';
        return 0;
    }
    QApplication app(argc, argv);
    const QString desktopId = qEnvironmentVariable("CIPHER_TRAFFIC_TEST_ID", "cipher-qt-traffic-test");
    QGuiApplication::setDesktopFileName(desktopId);
    app.setApplicationName("Cipher Qt traffic-light test");
    QWidget window(nullptr, Qt::Window | Qt::WindowTitleHint | Qt::WindowCloseButtonHint
                           | Qt::WindowMinimizeButtonHint | Qt::WindowMaximizeButtonHint);
    window.setWindowTitle("Cipher Qt traffic-light test");
    window.resize(660, 360);
    auto *layout = new QVBoxLayout(&window);
    auto *instructions = new QLabel("Try the red, yellow and green native title-bar buttons.\n"
                                    "Yellow: minimize; restore by clicking this app in the Dock.\n"
                                    "Green: maximize and restore; red: finish this test.");
    instructions->setWordWrap(true);
    instructions->setStyleSheet("font-size: 16px; padding: 16px;");
    layout->addWidget(instructions);
    auto *counter = new QLabel;
    layout->addWidget(counter);
    int seconds = 0;
    QTimer timer;
    QObject::connect(&timer, &QTimer::timeout, &window, [&] {
        counter->setText(QString("Live counter: %1 seconds").arg(++seconds));
    });
    timer.start(1000);
    window.show();
    return app.exec();
}
