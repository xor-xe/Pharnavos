// Colours + fonts. Shipped fonts are openly licensed (see CREDITS.md); headings and labels can be
// swapped for your own font files with fontHeading / fontLabel in ~/.local/state/pharnavos/settings.json.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root
  readonly property color red: "#FF3B3B"
  readonly property color cream: "#EDE6DA"
  readonly property color dim: "#2A2226"

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
  FontLoader { id: brushF; source: Rice.fontHeading ? "file://" + Rice.fontHeading : root.fontFile("firago-heavyitalic.ttf") }  // FiraGO (OFL)
  FontLoader { id: labelF; source: Rice.fontLabel ? "file://" + Rice.fontLabel : root.fontFile("bpg-excelsior-caps.ttf") }    // BPG Excelsior Caps (GPL)
  FontLoader { id: digitsF; source: root.fontFile("anton.ttf") }   // Anton (Google Fonts, OFL)
  FontLoader { id: wallF; source: root.fontFile("minecraft.ttf") }
}
