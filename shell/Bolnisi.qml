// The Bolnisi cross on a 24 grid: arms thin at the centre, flaring like trumpets. One outline, with two
// bars over the waist: Shape's curve renderer leaves a faint dark seam across the middle on its own.
import QtQuick
import QtQuick.Shapes

Item {
  id: root
  property color ink
  width: 24; height: 24
  Shape {
    anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
    ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.ink; PathSvg { path: "M11.25 11.25 Q11.41 6.96 8.14 3.94 Q12 5.78 15.86 3.94 Q12.59 6.96 12.75 11.25 Q17.04 11.41 20.06 8.14 Q18.22 12 20.06 15.86 Q17.04 12.59 12.75 12.75 Q12.59 17.04 15.86 20.06 Q12 18.22 8.14 20.06 Q11.41 17.04 11.25 12.75 Q6.96 12.59 3.94 15.86 Q5.78 12 3.94 8.14 Q6.96 11.41 11.25 11.25Z" } }
  }
  Rectangle { x: 11.2; y: 8; width: 1.6; height: 8; color: root.ink }
  Rectangle { x: 8; y: 11.2; width: 8; height: 1.6; color: root.ink }
}
