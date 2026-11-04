// Oliver: cielo de estrellas pixeladas detrás de TODA la barra (fondo negro puro).
// Tres capas con paralaje (lejanas lentas y tenues, cercanas más rápidas y
// brillantes), algunas parpadean en cruz y de vez en cuando cruza una estrella fugaz.
//
// Cómo funciona: este módulo ocupa 0 px en la fila de widgets y mete su Canvas
// en el fondo de la ventana de la barra (z negativo), así queda detrás de los
// iconos a lo ancho de toda la pantalla.
// La posición sale del reloj de pared: no salta al reiniciar el shell y va igual
// en todos los monitores.
// Ajustes en shell.json: "pixel": 2, "speed": 1, "density": 1
// Quitar: borra { "id": "starfield", "type": "qml" } de ~/.config/omarchy/shell.json
// Nota: bar/modules no se recarga en caliente -> `omarchy restart shell`.
import QtQuick
import Quickshell

Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  function num(key, def, lo, hi) {
    var v = settings && settings[key] !== undefined ? Number(settings[key]) : def
    if (!isFinite(v)) v = def
    return Math.max(lo, Math.min(hi, v))
  }
  readonly property int px: Math.round(num("pixel", 2, 1, 4))
  readonly property real speed: num("speed", 1, 0, 5)
  readonly property real density: num("density", 1, 0.2, 3)

  visible: !(bar && bar.vertical)
  implicitWidth: 0
  implicitHeight: 0

  readonly property var win: QsWindow.window
  readonly property Item host: win && win.contentItem ? win.contentItem : null

  // ------------------------------------------------------------ estrellas (semilla fija)
  // Cada capa: velocidad en px-arte/segundo, colores, tamaño.
  readonly property var layers: [
    { n: 70, v: 0.6, size: 1, cols: ["#3a3f58", "#454a66", "#3d4a5c"], tw: 0.0 },
    { n: 38, v: 1.6, size: 1, cols: ["#8a90b8", "#9aa8c8", "#b0a0c8", "#7f9fbf"], tw: 0.15 },
    { n: 14, v: 3.2, size: 1, cols: ["#ffffff", "#cfe8ff", "#ffe9a8", "#ffc8e6"], tw: 0.5 }
  ]
  property var stars: []

  function rng(seed) {
    var s = seed >>> 0
    return function() { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296 }
  }

  function build() {
    var r = rng(20261031)
    var out = []
    for (var l = 0; l < layers.length; l++) {
      var L = layers[l]
      var n = Math.round(L.n * density)
      for (var i = 0; i < n; i++) {
        out.push({
          layer: l,
          x: r(),                 // 0..1 del ancho total
          y: r(),                 // 0..1 de la altura útil
          col: L.cols[Math.floor(r() * L.cols.length)],
          tw: r() < L.tw,         // parpadea en cruz
          ph: r() * 10,           // fase del parpadeo
          per: 2 + Math.floor(r() * 5) // periodo en s (múltiplo del tick)
        })
      }
    }
    stars = out
  }
  Component.onCompleted: build()
  onDensityChanged: build()

  Canvas {
    id: sky
    parent: root.host
    visible: root.visible && parent !== null
    z: -1000
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    antialiasing: false
    smooth: false
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var p = root.px
      var cols = Math.ceil(width / p)
      var rows = Math.floor(height / p)
      if (cols <= 0 || rows <= 2) return
      var t = Date.now() / 1000
      var sp = root.speed

      function dot(cx, cy, c) {
        if (cy < 0 || cy >= rows) return
        cx = ((cx % cols) + cols) % cols
        ctx.fillStyle = c
        ctx.fillRect(cx * p, cy * p, p, p)
      }

      var st = root.stars
      for (var i = 0; i < st.length; i++) {
        var s = st[i]
        var L = root.layers[s.layer]
        // se mueven hacia la izquierda, cada capa a su velocidad
        var cx = Math.floor(s.x * cols - t * L.v * sp)
        var cy = 1 + Math.floor(s.y * (rows - 2))
        if (s.tw) {
          // parpadeo en pasos (sin fundidos: pixel art)
          var ph = Math.floor((t + s.ph) * 2) % (s.per * 2)
          if (ph === 0) {            // destello en cruz
            dot(cx, cy, "#ffffff")
            dot(cx - 1, cy, s.col); dot(cx + 1, cy, s.col)
            dot(cx, cy - 1, s.col); dot(cx, cy + 1, s.col)
          } else if (ph === 1) {     // apagándose
            dot(cx, cy, s.col)
          } else if (ph === s.per) { // un instante apagada
          } else dot(cx, cy, s.col)
        } else dot(cx, cy, s.col)
      }

      // estrella fugaz: una cada ~23 s, cruza en ~1.2 s, de derecha a izquierda bajando
      var cycle = 23, dur = 1.2
      var k = Math.floor(t / cycle)
      var u = (t - k * cycle) / dur
      if (sp > 0 && u >= 0 && u < 1) {
        var rr = root.rng(k * 7919 + 13)
        var x0 = Math.floor(cols * (0.35 + rr() * 0.6))
        var y0 = Math.floor(rr() * Math.max(1, rows / 3))
        var len = Math.min(140, Math.floor(cols * 0.12))
        var hx = Math.floor(x0 - u * len)
        var hy = Math.floor(y0 + u * (rows - 2 - y0))
        var tail = ["#ffffff", "#ffffff", "#cfe8ff", "#9ad7ff", "#5a86b8", "#33507a", "#22334f"]
        for (var j = 0; j < tail.length * 2; j++) {
          var fx = hx + j
          var fy = hy - Math.floor(j * (rows - 2 - y0) / Math.max(1, len))
          dot(fx, fy, tail[Math.floor(j / 2)])
        }
      }
    }
  }

  // 50 ms = 20 fps; los periodos de parpadeo son múltiplos de 0.5 s
  Timer {
    interval: 50
    repeat: true
    running: sky.visible && root.win && root.win.visible !== false
    onTriggered: sky.requestPaint()
  }
}
