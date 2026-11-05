// Colours + fonts. Shipped fonts are openly licensed (see CREDITS.md); headings and labels can be
// swapped for your own font files with fontHeading / fontLabel in ~/.local/state/pharnavos/settings.json.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
  id: root
  // colour themes, picked in the control centre: Crimson (the original) and Black Sea. Every reddish
  // colour in the shell goes through c(): Crimson keeps it, Black Sea turns its hue to blue and keeps
  // its lightness, so the wine-tinted greys become slate. Cream, amber, green and the power modes stay.
  // [id, name, swatch, hue, saturation factor, rose, pink]; gold stays toward yellow and calmer, so it
  // never reads orange. rose: the lighter tint beside the accent (the clock's დილის, the lock screen's
  // date); pink: a second hue for data next to the accent (battery, upload, a connected device)
  readonly property var themes: [["crimson", Rice.t("კრწანისი", "Crimson"), "#FF3B3B", -1, 1, "#FF5A66", "#E0607E"],
                                 ["blue", Rice.t("შავი ზღვა", "Black Sea"), "#3D9BE9", 0.575, 0.8, "#72D2EE", "#9AA8FF"],
                                 ["gold", Rice.t("ჭურჭელი", "Golden"), "#E3BE55", 0.13, 0.7, "#F2DB92", "#D0607A"],
                                 ["green", Rice.t("მინდორი", "Grassland"), "#62D87C", 0.37, 0.6, "#A6EBB0", "#B98BE0"]]
  readonly property var theme: themes.find(t => t[0] === Rice.cfg.theme) ?? themes[0]
  readonly property real hue: theme[3]
  function c(col) {
    const q = Qt.lighter(col, 1), h = q.hslHue;
    if (hue < 0 || h < 0 || q.hslSaturation === 0 || (h > 0.07 && h < 0.88)) return q;
    return Qt.hsla(hue, q.hslSaturation * theme[4], q.hslLightness, q.a);
  }
  function alpha(col, a) { return Qt.rgba(col.r, col.g, col.b, a) }
  readonly property color red: c("#FF3B3B")    // the accent ("red" from before there were themes)
  // window borders and their glow follow the theme (only while they're Pharnavos's own: PHARNAVOS_BORDERS);
  // again after a Hyprland config reload, which puts the configured ones back
  readonly property bool borders: Quickshell.env("PHARNAVOS_BORDERS") === "1"
  function hex(col, a) { return "rgba(" + col.toString().slice(1) + a + ")" }
  function paint() {
    if (!borders) return;
    const on = hex(red, "ff"), cr = hex(cream, "ff"), off = hex(c("#2A2226"), "cc"), glow = hex(red, "55");
    paintP.command = Rice.hyprLua
      ? ["hyprctl", "eval", "hl.config({ general = { col = { active_border = { colors = { \"" + on + "\", \"" + cr + "\", \"" + on + "\" }, angle = 45 }, inactive_border = \"" + off + "\" } }, decoration = { shadow = { color = \"" + glow + "\" } } })"]
      : ["hyprctl", "--batch", "keyword general:col.active_border " + on + " " + cr + " " + on + " 45deg ; keyword general:col.inactive_border " + off + " ; keyword decoration:shadow:color " + glow];
    paintP.running = true;
  }
  Process { id: paintP }
  onHueChanged: Qt.callLater(paint)   // after the colours that hang on the hue have caught up
  Connections { target: Rice; function onHyprLuaChanged() { root.paint() } }
  Connections { target: Hyprland; function onRawEvent(e) { if (e.name === "configreloaded") root.paint() } }
  Component.onCompleted: paint()
  readonly property color rose: theme[5]
  readonly property color pink: theme[6]
  readonly property color cream: "#EDE6DA"
  readonly property color dim: c("#2A2226")

  readonly property string brush: brushF.name     // headings, titles, greetings
  readonly property string label: labelF.name     // captions, tabs, date
  readonly property string digits: digitsF.name   // clock, percentages
  readonly property string wall: wallF.name       // wallpaper letters
  readonly property string sans: "Noto Sans Georgian"
  readonly property string mono: "FiraCode Nerd Font"

  // heading font for text that may be Latin (names, song titles): a heading font of your own may
  // have no Latin letters, so Latin text then falls back to the sans
  function headFor(n) { return Rice.fontHeading && /[A-Za-z]/.test(n) ? sans : brush }
  // same for the label font: your own may have no Latin letters
  function labelFor(n) { return Rice.fontLabel && /[A-Za-z]/.test(n) ? sans : label }

  // the icon theme's icon (empty if the theme doesn't have it)
  function iconFor(iconName) {
    return iconName ? (iconName.startsWith("/") ? "file://" + iconName : Quickshell.iconPath(iconName, true)) : "";
  }

  // date names in the UI language
  readonly property var days: Rice.lang === "en"
    ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    : ["კვირა", "ორშაბათი", "სამშაბათი", "ოთხშაბათი", "ხუთშაბათი", "პარასკევი", "შაბათი"]
  readonly property var daysShort: Rice.lang === "en"     // Monday first, for the calendar
    ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    : ["ორ", "სა", "ოთ", "ხუ", "პა", "შა", "კვ"]
  readonly property var months: Rice.lang === "en"
    ? ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    : ["იანვარი", "თებერვალი", "მარტი", "აპრილი", "მაისი", "ივნისი", "ივლისი", "აგვისტო", "სექტემბერი", "ოქტომბერი", "ნოემბერი", "დეკემბერი"]
  readonly property var monthsShort: Rice.lang === "en"
    ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    : ["იან", "თებ", "მარ", "აპრ", "მაი", "ივნ", "ივლ", "აგვ", "სექ", "ოქტ", "ნოე", "დეკ"]

  // clocks: fmt = 24 | ka (12 h + part of the day: დილის… / morning…) | ampm
  function time(d, fmt) { return fmt === "24" ? Qt.formatTime(d, "hh:mm") : ((d.getHours() + 11) % 12 + 1) + Qt.formatTime(d, ":mm") }
  // night = the hours the ka clock calls ღამის (22:00–5:59): the greeting follows the same line
  function night(d) { const h = d.getHours(); return h >= 22 || h < 6 }
  function period(d, fmt) {
    if (fmt === "ampm") return d.getHours() < 12 ? "AM" : "PM";
    if (fmt !== "ka") return "";
    const h = d.getHours();
    return h >= 6 && h < 12 ? Rice.t("დილის", "morning") : h >= 12 && h < 18 ? Rice.t("შუადღის", "afternoon")
         : night(d) ? Rice.t("ღამის", "night") : Rice.t("საღამოს", "evening");
  }

  function fontFile(f) { return "file://" + Quickshell.shellDir + "/assets/fonts/" + f }
  FontLoader { id: brushF; source: Rice.fontHeading ? "file://" + Rice.fontHeading : root.fontFile("mkhedruli-grunge-italic.ttf") }  // Mkhedruli Grunge (OFL)
  FontLoader { id: labelF; source: Rice.fontLabel ? "file://" + Rice.fontLabel : root.fontFile("bpg-excelsior-caps.ttf") }    // BPG Excelsior Caps (GPL)
  FontLoader { id: digitsF; source: root.fontFile("anton.ttf") }   // Anton (Google Fonts, OFL)
  FontLoader { id: wallF; source: root.fontFile("minecraft.ttf") }
}
