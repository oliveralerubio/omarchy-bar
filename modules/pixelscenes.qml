// Pixel-art mini escenas para el bar superior de Omarchy.
// Rota cada N min (por defecto 5): Kirby absorbiendo estrellas -> Link vs Octorok -> entrenador atrapando a Pikachu.
// La rotación va por reloj de pared: sobrevive a reinicios del shell y queda sincronizada entre monitores.
// Click = siguiente escena (reinicia sus 5 min). Ajustes en shell.json: "minutes": 5, "pixel": 2
// Quitar: borra la entrada { "id": "pixelscenes", "type": "qml" } de ~/.config/omarchy/shell.json
// Nota: los módulos de bar/modules no se recargan en caliente -> `omarchy restart shell`.
import QtQuick
import Quickshell

Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  // ---------------------------------------------------------------- config
  readonly property int cols: 80
  readonly property int rows: 12
  readonly property int barSize: bar && bar.barSize > 0 ? bar.barSize : 26
  readonly property int px: {
    var maxPx = Math.max(1, Math.floor((barSize - 2) / rows))
    var p = settings && settings.pixel !== undefined ? Math.floor(Number(settings.pixel)) : 2
    if (!isFinite(p) || p < 1) p = 2
    return Math.min(p, maxPx)
  }
  readonly property int sceneMs: {
    var m = settings && settings.minutes !== undefined ? Number(settings.minutes) : 5
    if (!isFinite(m) || m <= 0) m = 5
    return Math.max(10000, Math.round(m * 60000))
  }
  readonly property var sceneNames: ["Kirby absorbiendo estrellas", "Link vs Octorok", "¡Atrapa a Pikachu!"]

  // ---------------------------------------------------------------- estado (reloj de pared)
  property double shiftMs: 0
  property int scene: 0
  property double sceneStartMs: 0

  function effectiveNow() { return Date.now() - shiftMs }
  function currentScene() { return Math.floor(effectiveNow() / sceneMs) % 3 }
  function slotStart() { return Date.now() - (effectiveNow() % sceneMs) }

  function nextScene() {
    if (switchAnim.running) return
    shiftMs += (effectiveNow() % sceneMs) - sceneMs   // salta al inicio del siguiente slot
    checkScene()
  }

  function checkScene() {
    if (switchAnim.running) return
    if (currentScene() !== scene) switchAnim.start()
  }

  Component.onCompleted: { scene = currentScene(); sceneStartMs = slotStart() }
  onSceneMsChanged: { if (!switchAnim.running) { scene = currentScene(); sceneStartMs = slotStart() } }

  // ---------------------------------------------------------------- integración con el bar
  // contrato del bar: triggerPress -> click + cursor de mano; tooltipHovered -> tooltip
  property bool pressable: true
  property bool interactive: true
  function triggerPress(button) { nextScene() }
  readonly property bool tooltipHovered: visible && hover.hovered
  function tooltipText() { return sceneNames[scene] + "  ·  click: siguiente" }
  function refreshTooltip() {
    if (!bar) return
    if (tooltipHovered) { if (bar.showTooltip) bar.showTooltip(root, tooltipText()) }
    else if (bar.hideTooltip) bar.hideTooltip(root)
  }
  onTooltipHoveredChanged: refreshTooltip()
  onSceneChanged: if (tooltipHovered) refreshTooltip()

  readonly property var win: QsWindow.window
  readonly property bool shown: visible && (!win || win.visible !== false)

  visible: !(bar && bar.vertical)
  clip: true
  implicitWidth: cols * px + 8
  implicitHeight: barSize

  // efectos suaves teñidos con el color del tema (visibles en fondos claros y oscuros)
  readonly property string fgSoft: {
    var c = bar && bar.foreground ? Qt.color(bar.foreground) : Qt.color("#cfe8ff")
    if (!c || c.a === 0) c = Qt.color("#cfe8ff")
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ",0.6)"
  }

  // ---------------------------------------------------------------- sprites
  readonly property var kirbyPal: ({ K: "#2b1630", P: "#ffa6d1", p: "#ffe3f1", R: "#e8304f", B: "#1d1f5c", C: "#ff6aa8", M: "#4a0c1f" })
  readonly property var kirbyIdle: [
    "...KKKKK...",
    "..KPPPPPK..",
    ".KPpPPPPPK.",
    ".KPPPPBPBK.",
    "KPPPPPBPBPK",
    "KPPCPPPPCPK",
    "KPPPPPPMPPK",
    ".KPPPPPPPK.",
    ".KRRKKKRRK.",
    "KRRRK.KRRRK",
    ".KKK...KKK."
  ]
  // inhalando: boca grande y oscura a la derecha, una sola mejilla
  readonly property var kirbyInhale: [
    "...KKKKK...",
    "..KPPPPPKK.",
    ".KPpPPPPPPK",
    ".KPPPPBPBPK",
    "KPPPPPBPKKK",
    "KPPPPPPKMMM",
    "KPPCPPPKMMM",
    ".KPPPPPPKKK",
    ".KRRKKKRRK.",
    "KRRRK.KRRRK",
    ".KKK...KKK."
  ]
  readonly property var kirbyPuff: [
    "...KKKKKK...",
    ".KKPPPPPPKK.",
    "KPpPPPPBPBPK",
    "KPPPPPPBPBPK",
    "KPPCPPPPPPCK",
    "KPPPPPPPPPPK",
    "KPPPPPPPPPPK",
    ".KPPPPPPPPK.",
    ".KRRKKKKRRK.",
    "KRRRK..KRRRK",
    ".KKK....KKK."
  ]
  readonly property var starPal: ({ Y: "#ffe14d", W: "#ffffff" })
  readonly property var starBig: ["..Y..", ".YWY.", "YYYYY", ".YYY.", ".Y.Y."]
  readonly property var starSmall: [".Y.", "YWY", ".Y."]

  readonly property var linkPal: ({ g: "#1f6e2a", G: "#46b33f", H: "#7a4a22", S: "#f6c48f", K: "#1a1a1a", b: "#7a5230", Y: "#e9c03a" })
  // escudo al frente (hacia el enemigo)
  readonly property var link: [
    "....ggggg...",
    "..ggGGGGGg..",
    ".gGGGGGGGGg.",
    "gg.HHSSSSH..",
    "...HSSKSSK..",
    "....SSSSSS..",
    "...GGGGGGbb.",
    "..SGGGGGbYYb",
    "..HHHHHHbYYb",
    "...GGGGG.bb.",
    "...SS..SS...",
    "..HHH..HHH.."
  ]
  readonly property var linkAttack: [
    "....ggggg...",
    "..ggGGGGGg..",
    ".gGGGGGGGGg.",
    "gg.HHSSSSH..",
    "...HSSKSSK..",
    "....SSSSSS..",
    "..bbGGGGGGSY",
    ".bYYbGGGGG..",
    ".bYYbHHHHH..",
    "..bbGGGGG...",
    "..SS....SS..",
    ".HHH....HHH."
  ]
  readonly property var slash: ["..WW", ".W..", "W...", ".W..", "..WW"]
  readonly property var slashPal: ({ W: "#bfefff" })
  readonly property var octoPal: ({ R: "#e0393e", W: "#ffffff", K: "#111111", o: "#ff9a3c" })
  readonly property var octoA: [
    "..RRRR..",
    ".RRRRRR.",
    "RWKRRWKR",
    "RWKRRWKR",
    "oRRRRRRR",
    "oRRRRRR.",
    ".RRRRRR.",
    "R.R..R.R"
  ]
  readonly property var octoB: [
    "..RRRR..",
    ".RRRRRR.",
    "RWKRRWKR",
    "RWKRRWKR",
    "oRRRRRRR",
    "oRRRRRR.",
    ".RRRRRR.",
    ".R.RR.R."
  ]
  readonly property var rupeePal: ({ E: "#22c55e", e: "#bbf7d0" })
  readonly property var rupee: [".E.", "EeE", "EeE", "EEE", ".E."]

  readonly property var trainerPal: ({ R: "#e3343a", W: "#ffffff", K: "#1b1b1b", S: "#f4c08e", B: "#2f6fd6", D: "#26324d" })
  readonly property var trainer: [
    "..RRRRR....",
    ".RRWWRRR...",
    ".RRRRRRRRR.",
    ".KKSSSSS...",
    ".KSSSKSK...",
    "..SSSSS....",
    ".BBBWBBB...",
    "SBBBWBBBS..",
    "S.BBWBB.S..",
    "..DDDDD....",
    "..DD.DD....",
    ".RRR.RRR..."
  ]
  readonly property var trainerThrow: [
    "..RRRRR....",
    ".RRWWRRR...",
    ".RRRRRRRRR.",
    ".KKSSSSS...",
    ".KSSSKSK...",
    "..SSSSS....",
    ".BBBWBBBSS.",
    "SBBBWBBB...",
    "S.BBWBB....",
    "..DDDDD....",
    ".DD...DD...",
    "RRR...RRR.."
  ]
  // orejas abiertas con punta negra, cola en zigzag amarilla
  readonly property var pikaPal: ({ K: "#1b1b1b", Y: "#ffd93b", C: "#ff4b3e", t: "#8a5a1e" })
  readonly property var pikachu: [
    "K.......K...",
    ".Y.....Y....",
    ".YY...YY..YY",
    "..YYYYY..YY.",
    ".YKYYYKY..YY",
    ".CYYKYYC.Y..",
    "..YYYYY.t...",
    "..YYYYYt....",
    "..Y...Y....."
  ]
  readonly property var ballPal: ({ R: "#e3343a", K: "#1b1b1b", W: "#f5f5f5", Y: "#ffe14d" })
  readonly property var ball: [".RRR.", "RRRRR", "KKWKK", "WWWWW", ".WWW."]
  readonly property var ballFlip: [".WWW.", "WWWWW", "KKWKK", "RRRRR", ".RRR."]
  readonly property var ballClick: [".RRR.", "RRRRR", "KKYKK", "WWWWW", ".WWW."]
  readonly property var ballTiltL: ["RRR..", "RRRR.", "RKKWK", ".WWWW", "..WW."]
  readonly property var ballTiltR: ["..RRR", ".RRRR", "KWKKR", "WWWW.", ".WW.."]

  // ---------------------------------------------------------------- helpers de dibujo
  function dot(ctx, x, y, c) {
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
        ctx.fillStyle = col
        ctx.fillRect((x + c) * px, (y + r) * px, px, px)
      }
    }
  }

  function sparkle(ctx, x, y, size, c) {
    dot(ctx, x, y, "#ffffff")
    for (var i = 1; i <= size; i++) {
      dot(ctx, x + i, y, c); dot(ctx, x - i, y, c)
      dot(ctx, x, y + i, c); dot(ctx, x, y - i, c)
    }
  }

  // parpadeos con periodos múltiplos de 0.1 s (2 ticks del timer de 50 ms: sin aliasing)
  function blink(t, period) { return Math.floor(t / period) % 2 === 0 }

  function rnd(n) {
    var v = Math.sin(n * 127.1 + 311.7) * 43758.5453
    return v - Math.floor(v)
  }

  function grass(ctx, xs) {
    for (var i = 0; i < xs.length; i++) {
      dot(ctx, xs[i], 11, "#2f8f3a"); dot(ctx, xs[i] + 1, 10, "#46b33f"); dot(ctx, xs[i] + 2, 11, "#2f8f3a")
    }
  }

  // ---------------------------------------------------------------- escena 1: Kirby
  function kirbyScene(ctx, t) {
    var tw = [[22, 1], [34, 10], [46, 2], [57, 9], [69, 1], [76, 6], [40, 6], [62, 4]]
    for (var i = 0; i < tw.length; i++) {
      var b = Math.sin(t * 2.3 + i * 1.7)
      if (b > 0.35) dot(ctx, tw[i][0], tw[i][1], b > 0.85 ? "#ffffff" : fgSoft)
    }

    var lt = t % 6.0
    var kx = 3
    var ky = Math.sin(t * 4) > 0.4 ? 1 : 0

    if (lt < 4.6) {
      var mx = kx + 9, my = ky + 5
      // corrientes de aire hacia la boca
      for (i = 0; i < 7; i++) {
        var ph = (t * 1.4 + i / 7) % 1
        var e = ph * ph
        var wx = 76 - (76 - (mx + 3)) * e
        var wy = my + ((i % 3) - 1) * 4 * (1 - e)
        ctx.globalAlpha = 0.3 + 0.4 * e
        dot(ctx, wx, wy, fgSoft); dot(ctx, wx + 1, wy, fgSoft); dot(ctx, wx + 2, wy, fgSoft)
      }
      ctx.globalAlpha = 1
      spr(ctx, kirbyInhale, kirbyPal, kx, ky)
      // estrellas absorbidas (encima del sprite: el último punto entra en la boca)
      var startY = [3, 7, 4, 8]
      for (i = 0; i < 4; i++) {
        var s = i * 0.9
        if (lt < s || lt >= s + 1.5) continue
        var p = (lt - s) / 1.5
        var q = Math.pow(p, 1.4)
        var x = 76 + (mx - 76) * q
        var y = startY[i] + (my - startY[i]) * q + Math.sin(p * 12 + i) * 1.2 * (1 - p)
        if (p < 0.5) spr(ctx, starBig, starPal, x - 2, Math.max(0, y - 2))
        else if (p < 0.85) spr(ctx, starSmall, starPal, x - 1, y - 1)
        else dot(ctx, x, y, "#ffe14d")
      }
    } else if (lt < 5.3) {
      spr(ctx, kirbyPuff, kirbyPal, kx, ky)
    } else {
      spr(ctx, kirbyIdle, kirbyPal, kx, ky)
      if (blink(t, 0.2)) sparkle(ctx, kx + 14, ky + 2, 1, "#ffe14d")
      sparkle(ctx, kx + 17, ky + 6, 1, "#ff9ed2")
    }
  }

  // ---------------------------------------------------------------- escena 2: Link vs Octorok
  function zeldaScene(ctx, t) {
    grass(ctx, [26, 31, 39, 47, 53, 61, 68, 74])

    var lt = t % 3.6
    var lx = 5, ly = 0
    var hitX = 25                       // la punta de la espada (x=24) toca justo al enemigo
    var ey = 4
    var ex
    if (lt < 1.5) ex = 72 - (72 - hitX) * (lt / 1.5)
    else ex = hitX + Math.min(4, Math.max(0, (lt - 1.5) * 20))

    var attacking = lt >= 1.45 && lt < 1.9
    if (attacking) {
      var ax = lx + 1
      spr(ctx, linkAttack, linkPal, ax, ly)
      for (var k = 12; k <= 18; k++) dot(ctx, ax + k, ly + 6, k === 18 ? "#ffffff" : "#d8e2ff")
      dot(ctx, ax + 12, ly + 5, "#e9c03a"); dot(ctx, ax + 12, ly + 7, "#e9c03a")
      if (lt < 1.7) spr(ctx, slash, slashPal, ax + 13 + (lt < 1.55 ? 0 : 1), ly + 4)   // destello sobre la hoja, nunca sobre el enemigo
    } else {
      spr(ctx, link, linkPal, lx, ly)
    }

    // enemigo (se dibuja después de Link: la espada nunca le tapa la cara)
    if (lt < 1.5) {
      spr(ctx, blink(t, 0.1) ? octoA : octoB, octoPal, ex, ey)
    } else if (lt < 1.9) {
      spr(ctx, octoA, octoPal, ex, ey, blink(lt, 0.1) ? "#ffffff" : null)
    } else if (lt < 2.3) {
      // explosión: núcleo blanco + anillo de 12 partículas que se desvanece
      var u = (lt - 1.9) / 0.4
      var r = 1 + u * 3
      var cx = ex + 4, cy = ey + 4
      if (u < 0.3) { for (var dx = -1; dx <= 1; dx++) for (var dy = -1; dy <= 1; dy++) dot(ctx, cx + dx, cy + dy, "#ffffff") }
      var cols = ["#ffffff", "#ffd27a", "#ff8a3d"]
      ctx.globalAlpha = u > 0.7 ? 0.5 : 1
      for (var a = 0; a < 12; a++) {
        var ang = a * Math.PI / 6
        dot(ctx, cx + Math.cos(ang) * r, cy + Math.sin(ang) * r * 0.8, cols[a % 3])
      }
      ctx.globalAlpha = 1
    }

    // rupia: rebota y parpadea antes de desaparecer
    if (lt >= 2.2 && lt < 3.4) {
      var v = (lt - 2.2) / 1.2
      var bounce = Math.abs(Math.sin(v * Math.PI * 2.5)) * 4 * (1 - v)
      if (lt < 3.1 || blink(lt, 0.1)) {
        spr(ctx, rupee, rupeePal, ex + 3, 6 - bounce)
        if (blink(t, 0.3)) dot(ctx, ex + 5, 5 - bounce, "#ffffff")
      }
    }
  }

  // ---------------------------------------------------------------- escena 3: atrapar a Pikachu
  function pokemonScene(ctx, t) {
    var lt = t % 7.4
    var tx = 4, ty = 0
    var pkx = 62, pky = 3
    var bx = pkx + 3, groundY = 7

    grass(ctx, [18, 27, 36, 45, 53, 76])

    spr(ctx, (lt >= 1.45 && lt < 1.85) ? trainerThrow : trainer, trainerPal, tx, ty)

    // Pikachu libre (entra saltando desde la derecha al inicio de cada ciclo)
    if (lt < 2.6) {
      var enter = lt < 0.5 ? Math.round((1 - lt / 0.5) * 18) : 0
      var hop = Math.round(Math.abs(Math.sin(t * 6)) * 2)
      spr(ctx, pikachu, pikaPal, pkx + enter, pky - hop)
      var f = Math.floor(t * 10)
      if (enter === 0 && rnd(f) > 0.45) {
        var sx = pkx, sy = pky - hop + 5   // chispa pegada a la mejilla
        dot(ctx, sx, sy, "#fff176"); dot(ctx, sx - 1, sy - 1, "#ffe14d"); dot(ctx, sx - 1, sy + 1, "#ffe14d")
      }
    } else if (lt < 2.8) {
      // destello de captura: silueta brillante, opaca
      spr(ctx, pikachu, pikaPal, pkx, pky, blink(lt, 0.1) ? "#ffffff" : "#fff3b0")
    } else if (lt < 2.95) {
      // la luz colapsa hacia la pokébola
      var c = (lt - 2.8) / 0.15
      var cx = bx + 2, cy = 2
      var pts = [[pkx + 1, pky + 1], [pkx + 8, pky + 1], [pkx + 1, pky + 7], [pkx + 8, pky + 7]]
      for (var i = 0; i < 4; i++) dot(ctx, pts[i][0] + (cx - pts[i][0]) * c, pts[i][1] + (cy - pts[i][1]) * c, "#ffffff")
    }

    // pokébola
    if (lt >= 1.7 && lt < 2.6) {
      var u = (lt - 1.7) / 0.9
      var sx0 = tx + 10, sy0 = 4, ex0 = bx, ey0 = 4
      var x = sx0 + (ex0 - sx0) * u
      var y = sy0 + (ey0 - sy0) * u - 4 * Math.sin(Math.PI * u)   // ápice en y=0, sin recorte
      spr(ctx, blink(lt, 0.1) ? ball : ballFlip, ballPal, x, y)
    } else if (lt >= 2.6 && lt < 2.95) {
      spr(ctx, ball, ballPal, bx, 4 - (lt - 2.6) * 6)
    } else if (lt >= 2.95 && lt < 3.25) {
      var v = (lt - 2.95) / 0.3
      spr(ctx, ball, ballPal, bx, 2 + (groundY - 2) * v * v)
    } else if (lt >= 3.25 && lt < 6.6) {
      var sprite = ball, off = 0
      var wob = [3.5, 4.2, 4.9]          // 3 sacudidas con inclinación y pausa entre ellas
      for (var w = 0; w < 3; w++) {
        if (lt >= wob[w] && lt < wob[w] + 0.4) {
          var ph = (lt - wob[w]) / 0.4
          if (ph < 0.33) { sprite = ballTiltL; off = -1 }
          else if (ph < 0.66) { sprite = ballTiltR; off = 1 }
        }
      }
      var caught = lt >= 5.5
      if (caught) sprite = blink(lt, 0.2) ? ballClick : ball
      // se va parpadeando (sin fundido a alpha: sobre fondo oscuro quedaba turbio)
      if (lt < 6.2 || blink(lt, 0.1)) spr(ctx, sprite, ballPal, bx + off, groundY)
      if (caught && lt < 6.2) {
        var p2 = (lt - 5.5) / 0.7
        var sc = ["#ffe14d", "#ffffff", "#9ad7ff"]
        for (var s = 0; s < 3; s++) {
          var ang = -Math.PI / 2 + (s - 1) * 0.9
          var rr = 3 + p2 * 3
          sparkle(ctx, bx + 2 + Math.cos(ang) * rr, groundY + 2 + Math.sin(ang) * rr, 1, sc[s])
        }
      }
    }
    // 6.6 - 7.4: escena vacía (solo entrenador); luego Pikachu vuelve a entrar desde la derecha
  }

  function paintScene(ctx) {
    ctx.globalAlpha = 1
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    var t = (Date.now() - sceneStartMs) / 1000
    if (scene === 0) kirbyScene(ctx, t)
    else if (scene === 1) zeldaScene(ctx, t)
    else pokemonScene(ctx, t)
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

  // 20 fps; se pausa si el widget o su ventana no se muestran
  Timer {
    interval: 50
    running: root.shown
    repeat: true
    onTriggered: { root.checkScene(); canvas.requestPaint() }
  }

  SequentialAnimation {
    id: switchAnim
    NumberAnimation { target: canvas; property: "opacity"; to: 0; duration: 350 }
    ScriptAction { script: { root.scene = root.currentScene(); root.sceneStartMs = root.slotStart() } }
    NumberAnimation { target: canvas; property: "opacity"; to: 1; duration: 350 }
  }
}
