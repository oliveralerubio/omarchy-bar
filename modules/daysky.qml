// Oliver: cielo pixelado de DÍA detrás de TODA la barra (solo con temas CLAROS).
// Es el hermano de starfield.qml: allí estrellas sobre negro, aquí un cielo de
// bandas con nubes, un sol que cruza la barra con la hora real y, de vez en cuando,
// una bandada de pájaros o un globo aerostático.
//
//  - Cielo: bandas de azul claro (arriba) a azul pálido (abajo), con una fila
//    de tramado entre banda y banda. Sin degradado suave.
//  - Nubes: 3 capas con paralaje (lejanas pálidas y lentas, cercanas grandes con
//    3 tonos y más rápidas). Se mueven en pasos de píxel-arte hacia la izquierda.
//  - Sol: sale a las 6:30 por la izquierda y se pone a las 18:30 por la derecha
//    (hora local real). Brillo con parpadeo suave de 2 fotogramas.
//  - Hora del día: la última hora y media antes del ocaso y la primera hora tras
//    el amanecer el cielo se vuelve dorado/durazno (como el tema Tarde). De
//    noche con un tema claro queda un crepúsculo lavanda muy pálido, sin sol.
//  - Eventos raros (semilla = reloj de pared): V de pájaros cada pocos minutos y,
//    muy de vez en cuando, un globo.
//
// Cómo funciona: igual que starfield.qml. Ocupa 0 px en la fila de widgets y mete
// sus Canvas en el fondo de la ventana de la barra (z negativo). Todo sale del reloj
// de pared: no salta al reiniciar el shell y va igual en todos los monitores.
//
// Cuándo se ve: lee `mode` de ~/.local/state/omarchy/current/theme/colors.toml.
// Con mode = "light" se ve este cielo; con cualquier otro, starfield.qml
// (que se apaga en los temas claros). Cambia solo al cambiar de tema, sin reiniciar.
// El hook ~/.config/omarchy/hooks/theme-set.d/bar-text-by-mode.sh pone el [bar]
// de shell.toml (texto azul marino en claro, blanco sobre negro en oscuro).
//
// Ajustes en shell.json: "pixel": 2, "speed": 1, "density": 1,
//   "sunrise": 6.5, "sunset": 18.5  (horas locales decimales)
//   "hour": -1  (solo para probar: fija la hora, 14.5 = 14:30; -1 = hora real)
// Quitar: borra { "id": "daysky", "type": "qml" } de ~/.config/omarchy/shell.json
// Nota: bar/modules no se recarga en caliente -> `omarchy restart shell`.
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
  readonly property real sunrise: num("sunrise", 6.5, 0, 12)
  readonly property real sunset: num("sunset", 18.5, 12, 24)
  readonly property real hourOverride: num("hour", -1, -1, 24)

  // ------------------------------------------------------------ modo del tema
  readonly property string home: Quickshell.env("HOME")
  property bool day: false

  // Misma regla que omarchy-theme-color: `mode`, luego `theme_type`, y si no hay
  // ninguno, la luminosidad del fondo (suma de r+g+b > 382 = claro).
  function parseMode(raw) {
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
    if (/^#[0-9A-Fa-f]{6}$/.test(bg)) {
      return parseInt(bg.substr(1, 2), 16) + parseInt(bg.substr(3, 2), 16) + parseInt(bg.substr(5, 2), 16) > 382
    }
    return false
  }

  // Carga síncrona: así el modo ya se sabe cuando se crea el módulo (sin parpadeo).
  FileView {
    id: colorsFile
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    blockLoading: true
    printErrors: false
    onLoaded: root.day = root.parseMode(text())
    onLoadFailed: root.day = false
  }
  // `omarchy theme set` escribe theme.name DESPUÉS de dejar colors.toml listo.
  FileView {
    id: themeNameFile
    path: root.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: { themeNameFile.reload(); colorsFile.reload() }
  }
  // Red de seguridad por si se pierde un evento de inotify (la carpeta del tema se reemplaza entera).
  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: colorsFile.reload()
  }

  visible: !(bar && bar.vertical) && day
  implicitWidth: 0
  implicitHeight: 0

  readonly property var win: QsWindow.window
  readonly property Item host: win && win.contentItem ? win.contentItem : null

  // ------------------------------------------------------------ paletas
  // Cielo: 5 colores de arriba abajo. Contraste del azul marino #073642 >= 6.2:1 en todos.
  readonly property var skyDay:  ["#79c3ee", "#8ecff3", "#a4dbf6", "#bae6f9", "#cff0fb"]
  readonly property var skyWarm: ["#f1ae98", "#f6c1a0", "#f9d2a8", "#fbe0b4", "#fdecc4"]
  readonly property var skyDusk: ["#a7b2e0", "#b8c0e8", "#c9cff0", "#dadef5", "#eaecf9"]
  // Nubes: [luz, medio, sombra, lejana]
  readonly property var cloudDay:  ["#ffffff", "#e8f4fc", "#c8e1f1", "#d9eefa"]
  readonly property var cloudWarm: ["#fff7ec", "#fde6d2", "#f3c9b3", "#fbe0cc"]
  readonly property var cloudDusk: ["#f4f2fc", "#dedcf2", "#c5c2e4", "#d3d2ee"]
  // Sol: [núcleo, medio, borde, halo]
  readonly property var sunDay:  ["#fff6b8", "#ffe45e", "#ffc83d", "#fff6c0"]
  readonly property var sunWarm: ["#ffe9a0", "#ffb347", "#f08a3c", "#ffd9a0"]

  function hex2(c) { var s = Math.round(c).toString(16); return s.length < 2 ? "0" + s : s }
  function lerpCol(a, b, t) {
    if (t <= 0) return a
    if (t >= 1) return b
    var r = [0, 2, 4].map(function(i) {
      var x = parseInt(a.substr(1 + i, 2), 16), y = parseInt(b.substr(1 + i, 2), 16)
      return hex2(x + (y - x) * t)
    })
    return "#" + r.join("")
  }
  function lerpPal(a, b, t) {
    var out = []
    for (var i = 0; i < a.length; i++) out.push(lerpCol(a[i], b[i], t))
    return out
  }

  // Hora local decimal (o la de prueba).
  function hourNow() {
    if (hourOverride >= 0) return hourOverride
    var d = new Date()
    return d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600
  }

  // Pesos del tinte según la hora: wm = dorado, dk = crepúsculo (de noche).
  function tint(h) {
    var s = sunrise, d = sunset, wm = 0, dk = 0
    if (h >= s && h <= d) {
      if (h < s + 1) wm = 1 - (h - s)                 // 1 h tras el amanecer
      else if (h > d - 1.5) wm = (h - (d - 1.5)) / 1.5 // 1.5 h antes del ocaso
    } else if (h > d) {                                // tras el ocaso: dorado -> lavanda en 1 h
      dk = Math.min(1, h - d); wm = 1 - dk
    } else if (h >= s - 1) {                           // antes del amanecer: lavanda -> dorado
      dk = s - h; wm = 1 - dk
    } else dk = 1
    return { wm: Math.round(wm * 20) / 20, dk: Math.round(dk * 20) / 20 }
  }
  // `k` > 0 escalona el tinte por bandas: el dorado empieza por abajo (el horizonte) y sube,
  // así el cielo pasa de azul a durazno con un degradado de bandas y no por un gris sucio.
  function palette(day, warm, dusk, w, k) {
    var n = day.length - 1, out = []
    for (var i = 0; i < day.length; i++) {
      var lw = Math.max(0, Math.min(1, w.wm * (1 + k) - k * (1 - i / n)))
      // cada banda cambia de azul a durazno en un tramo corto (nunca queda en un gris intermedio mucho rato)
      if (k > 0) lw = Math.max(0, Math.min(1, (lw - 0.25) / 0.5))
      out.push(lerpCol(lerpCol(day[i], warm[i], lw), dusk[i], w.dk))
    }
    return out
  }

  // ------------------------------------------------------------ sprites
  // Nubes: '.' vacío, w luz, l medio, s sombra, f lejana (un solo tono).
  readonly property var cloudArt: ({
    far: [
      ["..ff.....", ".ffffff..", "fffffffff"],
      [".fff..", "ffffff"],
      ["...ff.......", ".ffffff.fff.", "ffffffffffff"]
    ],
    mid: [
      ["....ww.........", "..wwwwww..ww...", ".wwwwwwwwwwwww.", "lllllllllllllll"],
      [".....www...........", "...wwwwwww....www..", ".wwwwwwwwwwwwwwwwww", "lllllllllllllllllll"],
      ["...ww......", ".wwwwww.ww.", "wwwwwwwwwww", ".lllllllll."]
    ],
    near: [
      ["........www.............", "......wwwwwww....www.....", "..www.wwwwwwwwwwwwwww....", ".wwwwwwwwwwwwwwwwwwwww...",
       "wwwwwwwwwwwwwwwwwwwwwwww.", "llllllllllllllllllllllll.", ".ssssssssssssssssssssss.."],
      ["...........www.................", ".....www..wwwwwww...www.........", "...wwwwwwwwwwwwwwwwwwwwwwww.....", "..wwwwwwwwwwwwwwwwwwwwwwwwwww...",
       ".wwwwwwwwwwwwwwwwwwwwwwwwwwwww..", "lllllllllllllllllllllllllllllll.", ".ssssssssssssssssssssssssssss..."],
      ["......wwww.........", "....wwwwwwww.www....", "..wwwwwwwwwwwwwwww..", ".wwwwwwwwwwwwwwwwwww",
       "lllllllllllllllllll.", ".ssssssssssssssssss."]
    ]
  })
  // Pájaros (5x3), 4 fotogramas: alas arriba, planeo, alas abajo, planeo.
  readonly property var birdFrames: [
    ["x...x", ".x.x.", "..x.."],
    ["xx.xx", "..x..", "....."],
    ["..x..", ".x.x.", "x...x"],
    ["xx.xx", "..x..", "....."]
  ]
  // Globo (8x11): r rojo, R rojo oscuro, w franja blanca, k cuerdas, n cesta.
  readonly property var balloonArt: [
    "..rrrr..", ".rrwwrr.", "rrrwwrrR", "rrwwwwrR", "rrrwwrrR", "rrrwwrRR", ".rrwwrR.", "..rrRR..",
    "..k..k..", "..nnnn..", "..nnnn.."
  ]

  // ------------------------------------------------------------ nubes (semilla fija)
  function rng(seed) {
    var s = seed >>> 0
    return function() { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296 }
  }

  // Una nube cada `gap` columnas por capa; la lista depende del ancho (se rehace al cambiar).
  property var clouds: []
  property string cloudsKey: ""
  readonly property var cloudLayers: [
    { kind: "far",  gap: 58,  v: 0.8 },
    { kind: "mid",  gap: 105, v: 2.0 },
    { kind: "near", gap: 175, v: 4.0 }
  ]
  function buildClouds(cols, rows) {
    var key = cols + "x" + rows + "d" + density
    if (key === cloudsKey) return
    cloudsKey = key
    var r = rng(20261116)
    var out = []
    for (var l = 0; l < cloudLayers.length; l++) {
      var L = cloudLayers[l]
      var n = Math.max(1, Math.round(cols / L.gap * density))
      var variants = cloudArt[L.kind]
      for (var i = 0; i < n; i++) {
        var art = variants[Math.floor(r() * variants.length)]
        var flip = r() < 0.5
        var h = art.length
        var y
        if (L.kind === "far") y = Math.floor(r() * Math.max(1, rows - h - 1))
        else if (L.kind === "mid") y = Math.floor(r() * Math.max(1, rows - h))
        else y = rows - h + Math.floor(r() * 2)   // las grandes, abajo, como un banco de nubes
        out.push({ layer: l, kind: L.kind, art: art, flip: flip, y: y, x: (i + 0.15 + r() * 0.7) / n })
      }
    }
    clouds = out
  }

  // Lienzo estático: el cielo de bandas. Solo se repinta si cambia el tamaño o el tinte.
  Canvas {
    id: skyBg
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
      var p = root.px
      var cols = Math.ceil(width / p)
      var rows = Math.ceil(height / p)
      if (cols <= 0 || rows <= 0) return
      var pal = root.palette(root.skyDay, root.skyWarm, root.skyDusk, root.tint(root.hourNow()), 0.8)
      var n = pal.length - 1
      for (var y = 0; y < rows; y++) {
        // posición 0..n entre dos colores: por debajo de .35 el de arriba, por encima de .65
        // el de abajo y en medio un tramado de ajedrez (bandas con escalón, sin degradado)
        var g = rows > 1 ? y / (rows - 1) * n : 0
        var i = Math.min(n - 1, Math.floor(g))
        var f = g - i
        if (f < 0.35) { ctx.fillStyle = pal[i]; ctx.fillRect(0, y * p, width, p) }
        else if (f > 0.65 || i + 1 > n) { ctx.fillStyle = pal[i + 1]; ctx.fillRect(0, y * p, width, p) }
        else {
          ctx.fillStyle = pal[i]; ctx.fillRect(0, y * p, width, p)
          ctx.fillStyle = pal[i + 1]
          for (var x = y % 2; x < cols; x += 2) ctx.fillRect(x * p, y * p, p, p)
        }
      }
    }
  }

  // Lienzo animado: nubes, sol, pájaros y globo. Transparente salvo lo que dibuja.
  Canvas {
    id: scene
    parent: root.host
    visible: root.visible && parent !== null
    z: -999
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
      var rows = Math.ceil(height / p)
      if (cols <= 0 || rows <= 2) return
      var t = Date.now() / 1000
      var sp = root.speed
      var h = root.hourNow()
      var w = root.tint(h)
      var cc = root.palette(root.cloudDay, root.cloudWarm, root.cloudDusk, w, 0)
      var cmap = { w: cc[0], l: cc[1], s: cc[2], f: cc[3] }

      // tira horizontal de píxeles-arte; con `wrap` da la vuelta por los bordes (nubes)
      function run(x, y, len, c, wrap) {
        if (y < 0 || y >= rows || len <= 0) return
        ctx.fillStyle = c
        if (!wrap) {
          if (x < 0) { len += x; x = 0 }
          if (x + len > cols) len = cols - x
          if (len > 0) ctx.fillRect(x * p, y * p, len * p, p)
          return
        }
        x = ((x % cols) + cols) % cols
        if (x + len <= cols) ctx.fillRect(x * p, y * p, len * p, p)
        else {
          ctx.fillRect(x * p, y * p, (cols - x) * p, p)
          ctx.fillRect(0, y * p, (len - (cols - x)) * p, p)
        }
      }
      // sprite de filas de caracteres; `map` traduce carácter -> color
      function sprite(art, x, y, map, flip, wrap) {
        for (var r = 0; r < art.length; r++) {
          var row = flip ? art[r].split("").reverse().join("") : art[r]
          var c = 0
          while (c < row.length) {
            var ch = row.charAt(c)
            var e = c + 1
            while (e < row.length && row.charAt(e) === ch) e++
            if (ch !== "." && ch !== " " && map[ch]) run(x + c, y + r, e - c, map[ch], wrap)
            c = e
          }
        }
      }
      function layerClouds(l) {
        var L = root.cloudLayers[l]
        var cl = root.clouds
        for (var i = 0; i < cl.length; i++) {
          var o = cl[i]
          if (o.layer !== l) continue
          // paso entero de píxel-arte; hacia la izquierda, cada capa a su velocidad
          var cx = Math.floor(o.x * cols - t * L.v * sp)
          sprite(o.art, cx, o.y, cmap, o.flip, true)
        }
      }

      root.buildClouds(cols, rows)
      layerClouds(0)

      // ---- sol: de la izquierda (amanecer) a la derecha (ocaso), bajo y sin salir de la franja de día
      var u = (h - root.sunrise) / (root.sunset - root.sunrise)
      if (u >= 0 && u <= 1) {
        var sw = Math.round(w.wm * 20) / 20
        var sc = root.lerpPal(root.sunDay, root.sunWarm, Math.min(1, sw * 1.2))
        var rad = 4.5
        var scx = Math.round(u * (cols - 1))
        var scy = rows - 4 - Math.round(Math.sin(Math.PI * u) * rows * 0.28)
        var fr = Math.floor(t / 1.5) % 2   // brillo de 2 fotogramas
        // halo: ajedrez suave alrededor del disco que cambia de paridad en cada fotograma
        ctx.globalAlpha = 0.6
        for (var dy = -7; dy <= 7; dy++) {
          for (var dx = -7; dx <= 7; dx++) {
            var d2 = dx * dx + dy * dy
            if (d2 > rad * rad && d2 <= 6.3 * 6.3 && ((dx + dy + fr + 64) % 2 === 0)) run(scx + dx, scy + dy, 1, sc[3], false)
          }
        }
        ctx.globalAlpha = 1
        for (dy = -5; dy <= 5; dy++) {
          for (dx = -5; dx <= 5; dx++) {
            d2 = dx * dx + dy * dy
            if (d2 > rad * rad) continue
            run(scx + dx, scy + dy, 1, d2 <= 6 ? sc[0] : (d2 <= 14 ? sc[1] : sc[2]), false)
          }
        }
      }

      layerClouds(1)

      // ---- globo: muy de vez en cuando (cada ~15 min con probabilidad), deriva con el viento (izquierda)
      var bc = 900, bd = 260
      var bk = Math.floor(t / bc)
      var br = root.rng(bk * 6007 + 31)
      var bOn = br() < 0.7
      var bStart = bk * bc + br() * (bc - bd)
      var bu = (t - bStart) / bd
      if (sp > 0 && bOn && bu >= 0 && bu < 1) {
        var bx = Math.floor(cols + 2 - bu * (cols + 12))
        var by = 2 + Math.floor(br() * Math.max(1, rows - 15)) + (Math.floor(t / 4) % 2)   // sube y baja 1 px
        sprite(root.balloonArt, bx, Math.max(0, Math.min(rows - 11, by)),
               { r: "#e8584c", R: "#b8342b", w: "#fff6e8", k: "#6c4a1e", n: "#8a5a2b" }, false, false)
      }

      layerClouds(2)

      // ---- pájaros: V de 5 cada ~3 min (semilla = reloj), cruza en ~40 s
      var pc = 180, pd = 40
      var pk = Math.floor(t / pc)
      var pr = root.rng(pk * 7919 + 13)
      var pOn = pr() < 0.85
      var pStart = pk * pc + pr() * (pc - pd)
      var pu = (t - pStart) / pd
      if (sp > 0 && pOn && pu >= 0 && pu < 1) {
        var dir = pr() < 0.5 ? 1 : -1
        var py = 4 + Math.floor(pr() * Math.max(1, rows - 10))
        var lead = dir > 0 ? Math.floor(-14 + pu * (cols + 28)) : Math.floor(cols + 14 - pu * (cols + 28))
        var offs = [[0, 0], [-5, -2], [-5, 2], [-10, -4], [-10, 4]]
        var bmap = { x: "#1f4a63" }
        for (var b = 0; b < offs.length; b++) {
          var fi = (Math.floor(t * 5) + (b % 2)) % 4
          sprite(root.birdFrames[fi], lead + offs[b][0] * dir, py + offs[b][1], bmap, false, false)
        }
      }
    }
  }

  // Todos los módulos de la barra alinean su reloj a múltiplos del periodo en el reloj de pared:
  // así sus fotogramas caen en el mismo ciclo de dibujo y la ventana (y el desenfoque de
  // Hyprland) se actualiza una vez en vez de una por módulo.
  function alignedMs(ms) {
    var r = ms - Date.now() % ms
    return r < ms * 0.2 ? r + ms : r
  }

  // 100 ms = 10 fps: las nubes avanzan en pasos de 1 píxel, el sol y las aves usan fotogramas lentos.
  // El cielo (estático) solo se repinta si cambia el tamaño o el tinte de la hora.
  property string skyKey: ""
  Timer {
    interval: 100
    repeat: true
    running: scene.visible && root.win && root.win.visible !== false
    onRunningChanged: if (running) interval = root.alignedMs(100)
    onTriggered: {
      interval = root.alignedMs(100)
      var w = root.tint(root.hourNow())
      var key = skyBg.width + "x" + skyBg.height + ":" + w.wm + ":" + w.dk + ":" + root.px
      if (key !== root.skyKey) { root.skyKey = key; skyBg.requestPaint() }
      scene.requestPaint()
    }
  }
}
