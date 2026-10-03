
qt_add_resources(SOURCES resources.qrc)

set(qadwaitadecorations_SRCS
        qwhitesurgtkdecorationsplugin.cpp
        qwhitesurgtkdecorations.cpp
    ${SOURCES}
)

add_library(qwhitesurgtkdecorations MODULE ${qadwaitadecorations_SRCS})
target_link_libraries(qwhitesurgtkdecorations
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::GuiPrivate
    Qt${QT_VERSION_MAJOR}::Svg
    Qt${QT_VERSION_MAJOR}::WaylandClientPrivate
    Qt${QT_VERSION_MAJOR}::Widgets
    Qt${QT_VERSION_MAJOR}::DBus
)

if (NOT USE_QT6)
    if (${Qt5XkbCommonSupport_FOUND})
    target_link_libraries(qwhitesurgtkdecorations
        Qt${QT_VERSION_MAJOR}::XkbCommonSupportPrivate
        Qt${QT_VERSION_MAJOR}::ThemeSupportPrivate
    )
    endif()
endif()

install(TARGETS qwhitesurgtkdecorations DESTINATION ${QT_PLUGINS_DIR}/wayland-decoration-client)

