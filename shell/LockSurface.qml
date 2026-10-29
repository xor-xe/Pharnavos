// What the lock screen shows (design space 1600x900, scaled). Three looks:
//   giorgi — St. George (mirrored, no halo) made of flipping Georgian letters
//   flag   — the five-cross flag, full screen, in letters (whole-cell geometry, odd grid)
//   borj   — the collage Borjgali, turning faster with every keystroke
// The letter rain is one fragment shader (shaders/lockrain.frag) over a glyph atlas + a mask.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell

Item {
  id: ls
  property string variant: "giorgi"
  property string mood: "idle"          // idle | bad | ok
  property string message: ""
  property bool busy: false             // waiting for PAM
  property string clockFmt: "24"
  property int clearSeq: 0               // bumped by the lock: empty the field (every screen's)
  onClearSeqChanged: input.text = ""
  signal submitted(string password)
  signal escaped()
  signal edited()                        // typing again after a wrong password (the lock resets the mood)

  readonly property real s: height / 900
  readonly property int pwLen: input.text.length
  readonly property real heat: Math.min(1, pwLen / 6)
  focus: true
  Component.onCompleted: input.forceActiveFocus()

  Rectangle { anchors.fill: parent; color: "#000000" }

  // ---- letter rain (giorgi, flag) --------------------------------------------------------
  readonly property string glyphSet: "აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰႠႡႢႣႤႥႦႧႨႩႪႫႬႭ"
  // density: smaller cells = more letters in the stencil
  readonly property real cell: Math.round((variant === "flag" ? 12 : 9) * s)
  Row {
    id: atlasRow
    Repeater {
      model: ls.glyphSet.length
      // each glyph clipped to its own slot (no bleed into the neighbour), drawn at ~75% of the cell
      Item {
        required property int index
        width: ls.cell; height: ls.cell; clip: true
        Text { anchors.centerIn: parent; text: ls.glyphSet[parent.index]; color: "white"; font { family: Theme.sans; pixelSize: Math.round(ls.cell * 0.74); bold: true } }
      }
    }
  }
  ShaderEffectSource { id: atlasTex; sourceItem: atlasRow; hideSource: true; textureSize: Qt.size(atlasRow.width * 2, atlasRow.height * 2) }   // 2× for crisp glyphs

  // flag mask: 89 x 51 cells, one pixel per cell (black = letters)
  readonly property int fc: { const n = Math.floor(width / cell); return n % 2 ? n : n - 1 }
  readonly property int fr: { const n = Math.floor(height / cell); return n % 2 ? n : n - 1 }
  onFcChanged: flagMask.requestPaint()
  onFrChanged: flagMask.requestPaint()
  Canvas {
    id: flagMask
    width: ls.fc; height: ls.fr
    property bool ready: false
    onPainted: ready = true
    onPaint: {
      const ctx = getContext("2d");
      // proportions from the approved 89×51 design (k = 1 there), scaled to this grid
      const k = ls.fc / 89, cc = (ls.fc - 1) / 2, rc = (ls.fr - 1) / 2;
      const HW = Math.round(4 * k), L = Math.round(5 * k), arm = Math.round(1 * k), tip = Math.round(2 * k), fl = Math.max(1, Math.round(1 * k));
      const dx = Math.round(24 * k), dy = Math.round(15 * k);
      const small = [[cc - dx, rc - dy], [cc + dx, rc - dy], [cc - dx, rc + dy], [cc + dx, rc + dy]];
      const inSmall = (dc, dr) => {
        const a = Math.abs(dc), b = Math.abs(dr);
        return (a <= arm && b <= L) || (b <= arm && a <= L) || (b >= L - fl && b <= L && a <= tip) || (a >= L - fl && a <= L && b <= tip);
      };
      ctx.fillStyle = "white"; ctx.fillRect(0, 0, width, height); ctx.fillStyle = "black";
      for (let r = 0; r < ls.fr; r++) for (let c = 0; c < ls.fc; c++)
        if (Math.abs(c - cc) <= HW || Math.abs(r - rc) <= HW || small.some(([x, y]) => inSmall(c - x, r - y))) ctx.fillRect(c, r, 1, 1);
    }
  }
  ShaderEffectSource { id: flagTex; sourceItem: flagMask; hideSource: true; smooth: false }
  Image { id: giorgiImg; visible: false; source: "file://" + Quickshell.shellDir + "/assets/lock/st-george-silhouette.png" }

  property real clock: 0
  Timer { interval: 33; repeat: true; running: ls.variant !== "borj" && ls.visible; onTriggered: ls.clock += 0.033 }
  ShaderEffect {
    visible: ls.variant === "flag" ? flagMask.ready : ls.variant === "giorgi" && giorgiImg.status === Image.Ready
    anchors.fill: parent
    property variant atlas: atlasTex
    property variant mask: ls.variant === "flag" ? flagTex : giorgiImg
    property size res: Qt.size(width, height)
    // flag: odd grid with a true centre cell; giorgi: plain grid
    property point origin: ls.variant === "flag" ? Qt.point(width / 2 - ls.fc * ls.cell / 2, height / 2 - ls.fr * ls.cell / 2) : Qt.point(0, 0)
    property real cell: ls.cell
    property real t: ls.clock
    property real rate: 1 + (ls.mood !== "idle" ? 8 : 0)   // calm while typing; only a wrong/right answer stirs it
    property real heat: ls.heat
    property real glyphs: ls.glyphSet.length
    property real mood: ls.mood === "ok" ? 2 : ls.mood === "bad" ? 1 : 0
    property rect maskRect: ls.variant === "flag"
      ? Qt.rect(origin.x / width, origin.y / height, ls.fc * ls.cell / width, ls.fr * ls.cell / height)
      : Qt.rect(0, (height - width * 896 / 1600) / 2 / height, 1, width * 896 / 1600 / height)
    fragmentShader: "file://" + Quickshell.shellDir + "/shaders/lockrain.frag.qsb"
  }
  // flag: dark well behind the clock so it reads over the cross
  Shape {
    visible: ls.variant === "flag"
    anchors.fill: parent
    ShapePath {
      strokeWidth: 0; strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: ls.width / 2; centerY: ls.height / 2; focalX: centerX; focalY: centerY; centerRadius: 300 * ls.s
        GradientStop { position: 0; color: "#EB000000" }
        GradientStop { position: 0.6; color: "#BF000000" }
        GradientStop { position: 1; color: "#00000000" }
      }
      PathRectangle { width: ls.width; height: ls.height }
    }
  }

  // giorgi: soft dark well under the greeting + password so they read over the letters
  Shape {
    visible: ls.variant === "giorgi"
    anchors.fill: parent
    ShapePath {
      strokeWidth: 0; strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: ls.width / 2; centerY: 815 * ls.s; focalX: centerX; focalY: centerY; centerRadius: 230 * ls.s
        GradientStop { position: 0; color: "#E6000000" }
        GradientStop { position: 0.55; color: "#B3000000" }
        GradientStop { position: 1; color: "#00000000" }
      }
      PathRectangle { width: ls.width; height: ls.height }
    }
  }

  // ---- collage Borjgali (borj) ------------------------------------------------------------
  // speed in degrees per second; every frame (smooth even when a keystroke kicks it hard),
  // easing back to the slow idle turn
  property real spin: 0
  property real spd: 3.6
  FrameAnimation {
    running: ls.variant === "borj" && ls.visible
    onTriggered: {
      ls.spin = (ls.spin + ls.spd * frameTime) % 360;
      ls.spd = 3.6 + (ls.spd - 3.6) * Math.pow(0.21, frameTime);   // ≈ ×0.95 per 1/30 s
    }
  }
  onPwLenChanged: if (variant === "borj" && pwLen > 0) spd = Math.min(420, spd + 72 + Math.min(pwLen, 10) * 12)
  onMoodChanged: if (variant === "borj") spd = mood === "ok" ? 1200 : mood === "bad" ? -540 : spd
  Image {
    visible: ls.variant === "borj"
    width: 460 * ls.s; height: width
    x: ls.width / 2 - width / 2; y: 450 * ls.s - height / 2
    source: "file://" + Quickshell.shellDir + "/assets/cutouts/borjgali-collage.png"
    sourceSize: Qt.size(width, height); mipmap: true
    rotation: ls.spin
    scale: ls.mood === "ok" ? 1.3 : 1 + Math.min(7, ls.pwLen) * 0.03
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true; shadowHorizontalOffset: 0; shadowVerticalOffset: 0
      shadowColor: ls.mood === "ok" ? "#FFD27A" : "#FF2A3A"
      shadowBlur: ls.mood === "ok" ? 1 : ls.mood === "bad" ? 0.8 : 0.15 + Math.min(7, ls.pwLen) * 0.08
    }
  }

  // ---- clock, greeting, password ----------------------------------------------------------
  property var now: new Date()
  Timer { interval: 1000; running: true; repeat: true; onTriggered: ls.now = new Date() }
  readonly property real uiOp: mood === "ok" ? 0 : 1

  Column {
    opacity: ls.uiOp
    Behavior on opacity { NumberAnimation { duration: 600 } }
    // giorgi: centred in the empty top-left corner (the rider faces left, so the scene leaves it free)
    // giorgi + borj: centred in the top-left corner; flag: centred over the cross
    x: ls.variant === "flag" ? (ls.width - width) / 2 : 270 * ls.s - width / 2
    y: ls.variant === "flag" ? 300 * ls.s - height / 2 + 40 * ls.s : 175 * ls.s - height / 2
    spacing: 6 * ls.s
    // time (+ vertical part of the day) spans exactly the date's width: same left and right edge
    ClockMark {
      anchors.horizontalCenter: parent.horizontalCenter
      date: ls.now; fmt: ls.clockFmt; fitWidth: dateText.implicitWidth; outline: true
      wordColor: "#FF5A66"
    }
    Text {
      id: dateText
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#FF5A66"; style: Text.Outline; styleColor: "#000000"
      font { family: Theme.labelFor(text); pixelSize: (ls.variant === "borj" ? 24 : 20) * ls.s }
      text: Theme.days[ls.now.getDay()] + ", " + ls.now.getDate() + " "
            + Theme.months[ls.now.getMonth()]
    }
  }

  Column {
    opacity: ls.uiOp
    Behavior on opacity { NumberAnimation { duration: 600 } }
    // password: bottom centre (giorgi), under the clock (flag), bottom-right corner (borj)
    x: ls.variant === "borj" ? ls.width - 270 * ls.s - width / 2 : (ls.width - width) / 2
    y: (ls.variant === "giorgi" ? 780 : ls.variant === "flag" ? 560 : 775) * ls.s
    spacing: 10 * ls.s
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 7 * ls.s
      readonly property int h: ls.now.getHours()
      Text {
        id: greet
        // night as the clock's ღამის (Theme.night: 22:00–5:59), then morning / afternoon / evening
        text: (Theme.night(ls.now) ? Rice.t("ღამე მშვიდობისა", "Good night") : parent.h < 12 ? Rice.t("დილა მშვიდობისა", "Good morning") : parent.h < 18 ? Rice.t("გამარჯობა", "Hello") : Rice.t("საღამო მშვიდობისა", "Good evening")) + ","
        color: Theme.cream; style: Text.Outline; styleColor: "#000000"
        font { family: Theme.headFor(text); pixelSize: 24 * ls.s }
      }
      Text {
        anchors.baseline: greet.baseline; text: Rice.name
        color: Theme.cream; style: Text.Outline; styleColor: "#000000"
        font { family: Theme.headFor(Rice.name); pixelSize: 22 * ls.s; bold: true; italic: true }
      }
    }
    Rectangle {
      id: field
      anchors.horizontalCenter: parent.horizontalCenter
      // grows with the password; past 14 letters it stops and shows only the newest 14
      width: Math.max(260 * ls.s, typed.implicitWidth + 40 * ls.s); height: 38 * ls.s; radius: height / 2
      color: "#C7000000"; border.color: ls.mood === "bad" ? Theme.red : ls.busy ? Theme.cream : "#3A2E33"
      // checking: the border breathes
      property real w: 1
      border.width: ls.busy ? w : 1
      SequentialAnimation on w {
        running: ls.busy; loops: Animation.Infinite
        NumberAnimation { to: 2.5 * ls.s; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
      }
      Behavior on width { NumberAnimation { duration: 150 } }
      transform: Translate { id: shake }
      SequentialAnimation {
        running: ls.mood === "bad"
        NumberAnimation { target: shake; property: "x"; to: -14 * ls.s; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 12 * ls.s; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: -8 * ls.s; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: 4 * ls.s; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
      }
      Row {
        id: typed
        anchors.centerIn: parent
        spacing: 6 * ls.s
        opacity: ls.busy ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Repeater {
          model: Math.min(ls.pwLen, 14)
          Text {
            required property int index
            readonly property string set: "აბგდევზთიკლმნოპრსტუფქღყშჩცძწჭხჯჰ"
            readonly property int n: ls.pwLen - Math.min(ls.pwLen, 14) + index   // absolute position in the password
            text: set[(n * 7 + 3) % set.length]
            color: Theme.red; font { family: Theme.sans; pixelSize: 20 * ls.s; weight: Font.Black }
            scale: 0.4; opacity: 0
            Component.onCompleted: { scale = 1; opacity = 1 }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
          }
        }
      }
      Text {
        visible: ls.pwLen === 0
        anchors.centerIn: parent
        text: ls.busy ? "…" : Rice.t("პაროლი", "password")
        color: "#8C8186"; font { family: Theme.sans; pixelSize: 14 * ls.s; bold: true }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      height: 20 * ls.s
      text: ls.busy ? Rice.t("მოწმდება…", "Checking…") : ls.message; color: ls.busy ? "#C9C1C4" : Theme.red; style: Text.Outline; styleColor: "#000000"
      font { family: Theme.sans; pixelSize: 14 * ls.s; weight: Font.ExtraBold }
    }
  }

  TextInput {
    id: input
    visible: false
    focus: true
    echoMode: TextInput.Password
    enabled: !ls.busy && ls.mood !== "ok"
    onTextChanged: if (text.length && ls.mood === "bad") ls.edited()
    Keys.onReturnPressed: if (text.length) ls.submitted(text)
    Keys.onEnterPressed: if (text.length) ls.submitted(text)
    Keys.onEscapePressed: { if (text.length) text = ""; else ls.escaped() }
  }
  MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }
}
