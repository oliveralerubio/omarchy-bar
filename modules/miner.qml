// Minero en pixel art para el bar superior de Omarchy, reactivo a T3 Code.
// Mientras T3 Code tiene hilos trabajando, el minero pica una veta de cristal con la linterna
// encendida; cuando no hay nada corriendo, bosteza y se acuesta a dormir en la vagoneta (con zzz).
//
// Detección: cada pollSeconds consulta (solo lectura) la base de T3 Code
// ($HOME/.t3/userdata/statev2.sqlite) y cuenta los hilos con ejecución "running" que no están
// archivados ni borrados y cuyo updated_at es reciente (descarta ejecuciones zombi tras un crash).
// Si falta sqlite3 o la base, cuenta 0: el módulo se dibuja igual, durmiendo.
// Click = repetir la consulta ahora mismo.
//
// Ajustes en shell.json (todos opcionales):
//   "pixel": 2           tamaño del píxel de arte (se recorta al alto de la barra)
//   "pollSeconds": 4     cada cuántos segundos se consulta T3 Code
//   "staleMinutes": 20   un hilo "running" sin actualizarse en N min se considera zombi
// Quitar: borra la entrada { "id": "miner", "type": "qml" } de ~/.config/omarchy/shell.json
// Nota: los módulos de bar/modules no se recargan en caliente -> `omarchy restart shell`.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  // ---------------------------------------------------------------- config
  readonly property int cols: 46
  readonly property int rows: 12
  readonly property int barSize: bar && bar.barSize > 0 ? bar.barSize : 26
  readonly property int px: {
    var maxPx = Math.max(1, Math.floor((barSize - 2) / rows))
    var p = settings && settings.pixel !== undefined ? Math.floor(Number(settings.pixel)) : 2
    if (!isFinite(p) || p < 1) p = 2
    return Math.min(p, maxPx)
  }
  function num(key, def, lo, hi) {
    var v = settings && settings[key] !== undefined ? Number(settings[key]) : def
    if (!isFinite(v)) v = def
    return Math.max(lo, Math.min(hi, v))
  }
  readonly property int pollMs: Math.round(num("pollSeconds", 4, 1, 300) * 1000)
  readonly property int staleMinutes: Math.floor(num("staleMinutes", 20, 1, 1440))

  // ---------------------------------------------------------------- estado
  property int activeCount: 0          // hilos running ahora (lo escribe el poll)
  property double lastActiveMs: 0      // último instante con hilos corriendo (0 = nunca)
  property string mood: "sleeping"     // "working" | "sleeping" (lo decide decideState)
  property string lastMood: "sleeping"
  property double moodSinceMs: 0
  property double yawnUntilMs: 0       // working -> sleeping: bostezo antes de acostarse
  property double wakeUntilMs: 0       // sleeping -> working: signo de exclamación al despertar

  function decideState(activeCount, msSinceLastActive) {
    if (activeCount > 0) return "working"
    // Margen de gracia de 20 segundos antes de acostarse
    if (msSinceLastActive < 20000) return "working"
    return "sleeping"
  }

  // Se llama tras cada poll con el número de hilos activos.
  function applyCount(n) {
    activeCount = n
    var now = Date.now()
    if (activeCount > 0) lastActiveMs = now
    var since = lastActiveMs > 0 ? now - lastActiveMs : 1e12
    var r = decideState(activeCount, since)
    mood = r === "working" ? "working" : "sleeping"
  }

  onMoodChanged: {
    var now = Date.now()
    if (mood === "sleeping" && lastMood === "working") yawnUntilMs = now + 1500
    else if (mood === "working" && lastMood === "sleeping") wakeUntilMs = now + 500
    lastMood = mood
    moodSinceMs = now
    if (tooltipHovered) refreshTooltip()
  }

  // ---------------------------------------------------------------- consulta a T3 Code
  // Solo lectura (mode=ro). Cualquier fallo (sin sqlite3, sin base, error SQL) imprime 0.
  function probeCommand() {
    var sql = "SELECT COUNT(*) FROM orchestration_v2_projection_runs r " +
              "JOIN orchestration_v2_projection_threads t USING(thread_id) " +
              "WHERE r.status='running' AND t.archived_at IS NULL AND t.deleted_at IS NULL " +
              "AND julianday(t.updated_at) > julianday('now','-" + staleMinutes + " minutes');"
    return "db=\"$HOME/.t3/userdata/statev2.sqlite\"; " +
           "command -v sqlite3 >/dev/null 2>&1 || { echo 0; exit 0; }; " +
           "[ -f \"$db\" ] || { echo 0; exit 0; }; " +
           "sqlite3 \"file:$db?mode=ro\" \"" + sql + "\" 2>/dev/null || echo 0"
  }

  function poll() {
    if (probe.running) return          // nunca dos consultas a la vez
    probe.command = ["sh", "-c", probeCommand()]
    probe.running = true
  }

  Process {
    id: probe
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var n = parseInt(String(text || "").trim().split("\n")[0], 10)
        root.applyCount(isFinite(n) && n > 0 ? n : 0)
      }
    }
  }

  Timer {
    interval: root.pollMs
    running: root.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  // ---------------------------------------------------------------- integración con el bar
  // contrato del bar: triggerPress -> click + cursor de mano; tooltipHovered -> tooltip
  property bool pressable: true
  property bool interactive: true
  function triggerPress(button) { poll() }
  readonly property bool tooltipHovered: visible && hover.hovered
  function tooltipText() {
    if (mood === "working") {
      if (activeCount > 0)
        return "Minando · " + activeCount + (activeCount === 1 ? " hilo" : " hilos") + " en T3 Code"
      return "Minando · T3 Code acaba de terminar"
    }
    return "Durmiendo · T3 Code sin trabajo"
  }
  function refreshTooltip() {
    if (!bar) return
    if (tooltipHovered) { if (bar.showTooltip) bar.showTooltip(root, tooltipText()) }
    else if (bar.hideTooltip) bar.hideTooltip(root)
  }
  onTooltipHoveredChanged: refreshTooltip()
  onActiveCountChanged: if (tooltipHovered) refreshTooltip()

  readonly property var win: QsWindow.window
  readonly property bool shown: visible && (!win || win.visible !== false)

  visible: !(bar && bar.vertical)
  clip: true
  implicitWidth: cols * px + 8
  implicitHeight: barSize

  // ---------------------------------------------------------------- sprites
  readonly property var minerPal: ({
    h: "#b8861a", H: "#f2c230", L: "#fff6b0", l: "#5a5a46",
    S: "#f0b98a", K: "#1a1a1a", M: "#6b2a2a",
    B: "#3b6fb6", b: "#2a4f86", P: "#6b4a2b", O: "#2a2018"
  })
  // misma paleta con la linterna apagada
  readonly property var minerPalOff: ({
    h: "#b8861a", H: "#f2c230", L: "#5a5a46", l: "#5a5a46",
    S: "#f0b98a", K: "#1a1a1a", M: "#6b2a2a",
    B: "#3b6fb6", b: "#2a4f86", P: "#6b4a2b", O: "#2a2018"
  })
  // de pie, mirando a la veta (8x10); la luz sale de L
  readonly property var minerStand: [
    "..hHHh..",
    ".HHHHHHL",
    ".hhhhhhh",
    "..SSSSS.",
    "..SSSKS.",
    ".bBBBBBS",
    "..BBBBB.",
    "..PPPPP.",
    "..PP.PP.",
    ".OOO.OOO"
  ]
  // bostezo: brazos arriba y boca abierta
  readonly property var minerYawn: [
    "S.hHHh.S",
    "SHHHHHHS",
    ".hhhhhhh",
    "..SKSKS.",
    "..SMMMS.",
    "..BBBBB.",
    "..BBBBB.",
    "..PPPPP.",
    "..PP.PP.",
    ".OOO.OOO"
  ]
  // acostado en la vagoneta (10x4), la última fila queda tapada por el borde del carro
  readonly property var minerLieA: [
    "..HHH.....",
    ".HHHl.....",
    ".SKSBBBBPP",
    "SSSSBBBBPO"
  ]
  // inhalando: el pecho sube 1 px
  readonly property var minerLieB: [
    "..HHH.....",
    ".HHHlBBB..",
    ".SKSBBBBPP",
    "SSSSBBBBPO"
  ]

  readonly property var pickPal: ({ w: "#8a5a2b", m: "#c9d3dc", M: "#8b97a6" })
  // pico: origen (26,2) alzado, (26,5) en camino e impacto
  readonly property var pickRaised: [
    "..mmm..",
    "...wM..",
    "..w....",
    ".w.....",
    "w......"
  ]
  readonly property var pickMid: [
    ".....m.",
    "wwwwwmM",
    ".....m."
  ]
  readonly property var pickHit: [
    "......m.",
    "wwwwwwmM",
    "......m."
  ]

  readonly property var veinPal: ({ c: "#3de0ff", C: "#c4f8ff", p: "#a259ff", P: "#6a2fd0" })
  readonly property var vein: [
    "..Cc..",
    "cCccp.",
    "CccpPp",
    "ccCpP.",
    "cpPPp.",
    ".cpP.."
  ]

  readonly property var cartPal: ({
    K: "#9aa0ad", D: "#4d4659", d: "#38323f", r: "#7b7487",
    W: "#1e1b24", w: "#8a8f9c",
    g: "#6c6577", G: "#8d869a", c: "#3de0ff", C: "#c4f8ff"
  })
  readonly property var cart: [
    "KKKKKKKKKKKK",
    "dDDDDDDDDDDd",
    "dDrDDDDDDrDd",
    ".dDDDDDDDDd.",
    "..WwWddWwW..",
    "..WWW..WWW.."
  ]
  readonly property var pile: [
    "...gGC..",
    ".gGggcCg"
  ]

  readonly property var zPal: ({ Z: "#ffffff" })
  readonly property var zSmall: ["ZZZ", ".Z.", "ZZZ"]
  readonly property var zBig: ["ZZZ", "..Z", ".Z.", "ZZZ"]

  // borde izquierdo de la roca por fila (y = 0..11)
  readonly property var rockEdge: [37, 36, 35, 35, 34, 34, 34, 34, 35, 36, 36, 36]

  // ---------------------------------------------------------------- helpers de dibujo
  function dot(ctx, x, y, c) {
    if (y < 0 || y >= rows || x < 0 || x >= cols) return
    ctx.fillStyle = c
    ctx.fillRect(Math.round(x) * px, Math.round(y) * px, px, px)
  }

  function spr(ctx, s, pal, x, y, solid) {
    x = Math.round(x); y = Math.round(y)
    for (var r = 0; r < s.length; r++) {
      var row = s[r]
      for (var c = 0; c < row.length; c++) {
        var ch = row.charAt(c)
        if (ch === ".") continue
        var col = solid ? solid : pal[ch]
        if (!col) continue
        dot(ctx, x + c, y + r, col)
      }
    }
  }

  function rnd(n) {
    var v = Math.sin(n * 127.1 + 311.7) * 43758.5453
    return v - Math.floor(v)
  }

  // ---------------------------------------------------------------- fondo: roca, veta, rieles
  function drawRock(ctx) {
    for (var y = 0; y < rows; y++) {
      var e = rockEdge[y]
      for (var x = e; x < cols; x++) {
        var h = rnd(x * 13 + y * 7)
        var c = x === e ? "#1f1c28" : (h < 0.15 ? "#4a4358" : (h < 0.55 ? "#3a3445" : "#2c2836"))
        dot(ctx, x, y, c)
      }
    }
    spr(ctx, vein, veinPal, 34, 3)
  }

  // destellos escalonados en los cristales; en reposo más lentos
  function drawGlints(ctx, now, working) {
    var spots = [[36, 4], [37, 6], [36, 8], [35, 5]]
    var idx = Math.floor(now / (working ? 400 : 900)) % 8
    if (idx < spots.length) dot(ctx, spots[idx][0], spots[idx][1], "#ffffff")
  }

  function drawRail(ctx) {
    for (var x = 0; x < rockEdge[11]; x++) dot(ctx, x, 11, x % 4 === 0 ? "#4a3f35" : "#7a7d86")
  }

  function drawCart(ctx, withPile) {
    if (withPile) spr(ctx, pile, cartPal, 3, 3)
    spr(ctx, cart, cartPal, 1, 5)
  }

  // ---------------------------------------------------------------- estado: trabajando
  function drawCone(ctx, now) {
    if (rnd(Math.floor(now / 200)) > 0.93) return        // parpadeo ocasional de la linterna
    ctx.fillStyle = "#fff3a0"
    for (var d = 1; d <= 7; d++) {
      var x = 26 + d
      var cy = 2 + Math.round(d * 0.5)
      var hw = Math.floor(d / 3)
      ctx.globalAlpha = d < 4 ? 0.24 : 0.12
      for (var y = cy - hw; y <= cy + hw; y++) ctx.fillRect(x * px, y * px, px, px)
    }
    ctx.globalAlpha = 1
  }

  function workingScene(ctx, now) {
    var step = Math.floor(now / 250)
    var phase = step % 3                 // 0 alzado, 1 golpe en camino, 2 impacto
    var cycle = Math.floor(step / 3)
    var waking = now < wakeUntilMs

    drawCone(ctx, now)
    drawCart(ctx, true)
    spr(ctx, minerStand, minerPal, 18, 1)

    if (waking) {
      // "!" de sorpresa a la izquierda de la cabeza
      dot(ctx, 16, 0, "#ff5a4d"); dot(ctx, 16, 1, "#ff5a4d"); dot(ctx, 16, 3, "#ff5a4d")
      spr(ctx, pickRaised, pickPal, 26, 2)
      return
    }

    if (phase === 0) spr(ctx, pickRaised, pickPal, 26, 2)
    else if (phase === 1) spr(ctx, pickMid, pickPal, 26, 5)
    else spr(ctx, pickHit, pickPal, 26, 5)

    if (phase === 2) {
      // chispas en el impacto (dos variantes según el ciclo)
      if (cycle % 2 === 0) {
        dot(ctx, 33, 4, "#ffffff"); dot(ctx, 32, 3, "#ffd84d")
        dot(ctx, 33, 8, "#ffffff"); dot(ctx, 32, 9, "#ff9a3c")
      } else {
        dot(ctx, 33, 4, "#ffd84d"); dot(ctx, 31, 4, "#ffffff")
        dot(ctx, 33, 8, "#ff9a3c"); dot(ctx, 31, 8, "#ffffff")
      }
      dot(ctx, 35, 5, "#ffffff")
    } else if (phase === 0 && rnd(cycle) > 0.5) {
      // trocitos de roca que caen tras el golpe
      dot(ctx, 33, 8, "#4a4358"); dot(ctx, 32, 9, "#3a3445"); dot(ctx, 33, 10, "#4a4358")
    }
  }

  // ---------------------------------------------------------------- estado: durmiendo
  // zzz que suben en pasos de píxel; el color se apaga por escalones, sin degradados
  function drawZ(ctx, now) {
    var period = 4500
    var shades = ["#5d6a99", "#8fa2e6", "#cfe0ff", "#cfe0ff", "#8fa2e6", "#5d6a99"]
    var ys = [4, 3, 2, 1, 0, 0]
    for (var i = 0; i < 3; i++) {
      var p = ((now + i * 1500) % period) / period
      var k = Math.min(5, Math.floor(p * 6))
      var big = k === 2 || k === 3
      var s = big ? zBig : zSmall
      var x = 13 + k * 2 + (k % 2)
      var y = big ? ys[k] - 1 : ys[k]
      if (y < 0) y = 0
      var col = shades[k]
      // último escalón: media trama (tablero) para que "se deshaga" en píxeles
      for (var r = 0; r < s.length; r++)
        for (var c = 0; c < s[r].length; c++) {
          if (s[r].charAt(c) === ".") continue
          if (k === 5 && (r + c) % 2 === 1) continue
          dot(ctx, x + c, y + r, col)
        }
    }
  }

  function sleepingScene(ctx, now) {
    if (now < yawnUntilMs) {
      // bostezo y estiramiento antes de acostarse: la primera parte con brazos arriba
      var left = yawnUntilMs - now
      drawCart(ctx, true)
      spr(ctx, left > 600 ? minerYawn : minerStand, minerPalOff, 18, left > 600 ? 1 : 2)
      return
    }
    var inhale = Math.floor(now / 750) % 2 === 1       // sube 1 px cada ~1.5 s
    spr(ctx, inhale ? minerLieB : minerLieA, minerPalOff, 2, 2)
    drawCart(ctx, false)
    drawZ(ctx, now)
  }

  function paintScene(ctx) {
    ctx.globalAlpha = 1
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    var now = Date.now()
    var working = mood === "working"
    drawRock(ctx)
    drawGlints(ctx, now, working)
    drawRail(ctx)
    if (working) workingScene(ctx, now)
    else sleepingScene(ctx, now)
  }

  // ---------------------------------------------------------------- runtime
  HoverHandler { id: hover }

  Canvas {
    id: canvas
    anchors.centerIn: parent
    width: root.cols * root.px
    height: root.rows * root.px
    antialiasing: false
    smooth: false
    renderStrategy: Canvas.Cooperative
    onPaint: root.paintScene(getContext("2d"))
  }

  // 10 fps (el golpe va a 250 ms por cuadro); se pausa si el widget o su ventana no se muestran
  Timer {
    interval: 100
    running: root.shown
    repeat: true
    onTriggered: canvas.requestPaint()
  }
}
