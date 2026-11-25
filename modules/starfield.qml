// Oliver: cielo de estrellas pixeladas detrás de TODA la barra (fondo negro puro).
// Tres capas con paralaje (lejanas lentas y tenues, cercanas más rápidas y
// brillantes), algunas parpadean en cruz y de vez en cuando cruza una estrella fugaz.
//
// Cómo funciona: este módulo ocupa 0 px en la fila de widgets y mete su Canvas
// en el fondo de la ventana de la barra (z negativo), así queda detrás de los
// iconos a lo ancho de toda la pantalla.
// La posición sale del reloj de pared: no salta al reiniciar el shell y va igual
// en todos los monitores.
// Ajustes en shell.json: "pixel": 2, "speed": 1, "density": 1, "fps": 10
// ("fps": cuadros por segundo del cielo; por defecto 10, o más con "speed" alto (20 con speed 5),
//  y 20 mientras cruza la estrella fugaz.
//  Las estrellas avanzan 1-6 px/s, así que a 10 fps no se nota y se pinta la mitad; "fps": 20 = como antes)
// Quitar: borra { "id": "starfield", "type": "qml" } de ~/.config/omarchy/shell.json
// Nota: bar/modules no se recarga en caliente -> `omarchy restart shell`.
//
// Temas CLAROS: este módulo se apaga solo (mode = "light" en colors.toml) y lo
// sustituye el cielo de día de daysky.qml. En temas oscuros todo sigue igual.
import QtQuick
import Quickshell
import Quickshell.Io

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
  // Por defecto, lo justo para que la capa más rápida (3.2 px-arte/s × speed) no avance más de
  // ~1 px-arte por cuadro: 10 fps con speed ≤ 2.5 y hasta 20 (como antes) con speed 5.
  readonly property int autoFps: Math.min(20, Math.max(10, Math.ceil(3.2 * speed * 1.25)))
  readonly property int fps: Math.round(num("fps", autoFps, 5, 30))

  // ---- modo del tema (misma regla que daysky.qml y omarchy-theme-color)
  readonly property string home: Quickshell.env("HOME")
  property bool lightMode: false
  function parseLight(raw) {
    var mode = "", type = "", bg = ""
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?([^"'#\s]*)/)
      if (!m) continue
      if (m[1] === "mode") mode = m[2]
      else if (m[1] === "theme_type") type = m[2]
      else if (m[1] === "background") bg = m[2]
    }
    var v = mode || type
    if (v) return v === "light"
    if (/^#[0-9A-Fa-f]{6}$/.test(bg))
      return parseInt(bg.substr(1, 2), 16) + parseInt(bg.substr(3, 2), 16) + parseInt(bg.substr(5, 2), 16) > 382
    return false
  }
  FileView {
    id: colorsFile
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    blockLoading: true
    printErrors: false
    onLoaded: root.lightMode = root.parseLight(text())
    onLoadFailed: root.lightMode = false
  }
  // `omarchy theme set` escribe theme.name DESPUÉS de dejar colors.toml listo.
  FileView {
    id: themeNameFile
    path: root.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: { themeNameFile.reload(); colorsFile.reload() }
  }
  // Red de seguridad por si se pierde un evento de inotify.
  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: colorsFile.reload()
  }

  visible: !(bar && bar.vertical) && !lightMode
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

  // Los pasos de las estrellas son de 1 px-arte a 0.6-3.2 px/s y los periodos de parpadeo
  // múltiplos de 0.5 s, así que basta `fps` cuadros por segundo (10 = 100 ms). Mientras cruza la
  // estrella fugaz (1.2 s cada 23 s) se sube a 20 fps para que su estela siga igual de fluida.
  function nextTickMs() {
    var t = Date.now() / 1000
    var fast = speed > 0 && ((t % 23) < 1.2 || (t % 23) > 22.85)
    return fast ? 50 : Math.round(1000 / fps)
  }
  // Todos los módulos de la barra alinean su reloj a múltiplos del periodo en el reloj de pared:
  // así sus fotogramas caen en el mismo ciclo de dibujo y la ventana (y el desenfoque de
  // Hyprland) se actualiza una vez en vez de una por módulo.
  function alignedMs(ms) {
    var r = ms - Date.now() % ms
    return r < ms * 0.2 ? r + ms : r
  }
  Timer {
    interval: 100
    repeat: true
    running: sky.visible && root.win && root.win.visible !== false
    onRunningChanged: if (running) interval = root.alignedMs(root.nextTickMs())
    onTriggered: {
      interval = root.alignedMs(root.nextTickMs())
      sky.requestPaint()
    }
  }
}
