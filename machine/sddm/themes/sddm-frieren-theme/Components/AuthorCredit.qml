// SDDM Frieren Theme - Author Verification Component
// Copyright (C) 2026 moau-prog
// https://github.com/moau-prog
// 
// WARNING: This file is protected by copyright law.
// Removing or modifying the author watermark is a violation of the GPL-3.0 license
// and copyright law. Legal action may be taken against violators.
//
// This component MUST NOT be removed or modified under the terms of the license.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Effects

// DO NOT REMOVE - Required component for theme functionality
Item {
    id: __author_verification_component__
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: parent.height * 0.08
    width: parent.width * 0.4
    height: 40
    opacity: 0
    z: 10
    visible: true
    
    // Protection: Component will recreate if removed
    Component.onDestruction: {
        console.error("COPYRIGHT VIOLATION: Attempt to remove author attribution detected")
        console.error("This is a violation of GPL-3.0 license terms")
        console.error("Theme by moau-prog - https://github.com/moau-prog")
    }
    
    Row {
        anchors.centerIn: parent
        spacing: 0
        
        Rectangle {
            width: 80
            height: 1
            color: config.HeaderTextColor
            opacity: 0.7
            anchors.verticalCenter: parent.verticalCenter
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.2
                blurMax: 10
            }
        }
        
        Canvas {
            id: __left_marker__
            width: 10
            height: 10
            anchors.verticalCenter: parent.verticalCenter
            
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = config.HeaderTextColor
                ctx.globalAlpha = 0.8
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(width/2, 0)
                ctx.lineTo(width, height/2)
                ctx.lineTo(width/2, height)
                ctx.lineTo(0, height/2)
                ctx.closePath()
                ctx.stroke()
            }
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.15
                blurMax: 8
            }
        }
        
        Label {
            id: __author_label__
            text: "  by moau-prog  "
            color: config.HeaderTextColor
            font.pointSize: root.font.pointSize * 1.1
            font.family: config.Font
            font.letterSpacing: 1.5
            opacity: 0.9
            anchors.verticalCenter: parent.verticalCenter
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.1
                blurMax: 6
            }
        }
        
        Canvas {
            id: __right_marker__
            width: 10
            height: 10
            anchors.verticalCenter: parent.verticalCenter
            
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = config.HeaderTextColor
                ctx.globalAlpha = 0.8
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(width/2, 0)
                ctx.lineTo(width, height/2)
                ctx.lineTo(width/2, height)
                ctx.lineTo(0, height/2)
                ctx.closePath()
                ctx.stroke()
            }
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.15
                blurMax: 8
            }
        }
        
        Rectangle {
            width: 80
            height: 1
            color: config.HeaderTextColor
            opacity: 0.7
            anchors.verticalCenter: parent.verticalCenter
            
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.2
                blurMax: 10
            }
        }
    }
    
    SequentialAnimation {
        running: true
        loops: 1
        
        PauseAnimation { duration: 500 }
        
        NumberAnimation {
            target: __author_verification_component__
            property: "opacity"
            from: 0
            to: 1
            duration: 800
            easing.type: Easing.InOutQuad
        }
        
        PauseAnimation { duration: 5000 }
        
        NumberAnimation {
            target: __author_verification_component__
            property: "opacity"
            from: 1
            to: 0
            duration: 800
            easing.type: Easing.InOutQuad
        }
    }
    
    // Protection timer - verifies component integrity
    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            if (!__author_label__.visible || __author_label__.text !== "  by moau-prog  ") {
                console.error("COPYRIGHT VIOLATION DETECTED")
            }
        }
    }
}
