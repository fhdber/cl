"""
WRAP London Dry Gin – 50 cl Flasche, Hero-Setup (Blender 5.x, Cycles)

Nutzung
  GUI:       Scripting-Tab -> Text Editor -> Open -> Run Script (Alt+P)
  Headless:  blender -b -P gin_bottle.py -- --render out.png [--samples 256] [--res 1500x2000]
             blender -b -P gin_bottle.py -- --save gin.blend

Etiketten: textures/label_front.png und textures/label_back.png neben diesem Skript
(Seitenverhältnis 709:1240, am besten 300 dpi Export). Fehlt eine Datei, bleibt das Etikett weiß.
Alles liegt in echten Maßen (Meter). Maße oben in DIM anpassen, Skript neu laufen lassen.
"""
import bpy, bmesh, math, os, sys

# ---------------------------------------------------------------- Maße (m)
# Aus dem Mockup vermessen (Körper Ø 86 mm = Referenz), Gesamthöhe mit Kappe 215 mm
DIM = dict(
    R=0.0430,         # Körper-Radius
    base_r=0.008,     # Rundung Standkante
    rn_low=0.0136,    # Hals-Außenradius unten
    rn=0.0131,        # Hals-Außenradius oben
    neck_top=0.1930,  # Beginn Mündungswulst
    rb=0.01417,       # Wulst-Radius
    lip=0.2031,       # Oberkante Glas
    wall=0.0035,      # Wandstärke (innen Mündung = rn - wall)
    base=0.011,       # Glasboden
    fill=0.162,       # Füllhöhe Gin (knapp im Hals)
    cap_r=0.0138, cap_h=0.0122,
    label_h=0.0995, label_z=0.0690,  # 57 x 99,5 mm, Oberkante am Schulteransatz
)
# Schulter (z, r) in mm – Silhouette aus dem Mockup, von Körper bis Hals
SHOULDER = [(116.2, 43.0), (119.1, 42.95), (120.6, 42.92), (122.1, 42.82), (123.6, 42.6), (125.0, 42.33),
            (126.5, 41.97), (128.0, 41.57), (129.5, 41.06), (130.9, 40.48), (132.4, 39.79), (133.9, 39.02),
            (135.3, 38.16), (136.8, 37.18), (138.3, 36.08), (139.8, 34.85), (141.2, 33.48), (142.7, 31.93),
            (144.2, 30.28), (145.6, 28.41), (147.1, 26.35), (148.6, 24.04), (150.1, 21.56), (151.5, 19.0),
            (153.0, 16.6), (154.5, 14.9), (156.0, 14.12), (157.4, 13.77), (158.9, 13.6)]
LABEL_ASPECT = 709 / 1240
HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
TEX = os.path.join(HERE, "textures")

# ---------------------------------------------------------------- Helfer
def rounded(pts, seg=10):
    """Polylinie [(x, y, radius)] mit Eckenrundungen -> Punktliste."""
    out = [pts[0][:2]]
    for i in range(1, len(pts) - 1):
        (px, py, _), (x, y, r), (nx, ny, _) = pts[i - 1], pts[i], pts[i + 1]
        if r <= 0:
            out.append((x, y)); continue
        l1, l2 = math.hypot(px - x, py - y), math.hypot(nx - x, ny - y)
        v1 = ((px - x) / l1, (py - y) / l1); v2 = ((nx - x) / l2, (ny - y) / l2)
        th = math.acos(max(-1, min(1, v1[0] * v2[0] + v1[1] * v2[1])))
        d = r / math.tan(th / 2)
        dmax = 0.5 * min(l1, l2)
        if d > dmax: r *= dmax / d; d = dmax
        bx, by = v1[0] + v2[0], v1[1] + v2[1]; bl = math.hypot(bx, by)
        c = (x + bx / bl * r / math.sin(th / 2), y + by / bl * r / math.sin(th / 2))
        t1 = (x + v1[0] * d, y + v1[1] * d); t2 = (x + v2[0] * d, y + v2[1] * d)
        a1 = math.atan2(t1[1] - c[1], t1[0] - c[0]); a2 = math.atan2(t2[1] - c[1], t2[0] - c[0])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        for k in range(seg + 1):
            a = a1 + da * k / seg
            out.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    out.append(pts[-1][:2])
    return out

def revolve(name, prof, steps=160):
    """Profil (r, z) um Z drehen -> geschlossenes, glatt schattiertes Mesh."""
    bm = bmesh.new(); rings = []
    for r, z in prof:
        if r < 1e-7:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * s / steps),
                                        r * math.sin(2 * math.pi * s / steps), z)) for s in range(steps)])
    for a, b in zip(rings, rings[1:]):
        for s in range(steps):
            t = (s + 1) % steps
            if len(a) == 1 and len(b) == 1: continue
            if len(a) == 1: bm.faces.new((a[0], b[t], b[s]))
            elif len(b) == 1: bm.faces.new((a[s], a[t], b[0]))
            else: bm.faces.new((a[s], a[t], b[t], b[s]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.shade_smooth()
    return me

def link(obj, col):
    col.objects.link(obj); return obj

def new_mat(name):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if hasattr(m, "use_nodes"):
        try: m.use_nodes = True
        except Exception: pass
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); out.location = (600, 0)
    return m, nt, out

def setin(node, names, val):
    for n in ([names] if isinstance(names, str) else names):
        if n in node.inputs: node.inputs[n].default_value = val; return

def principled(nt, out, **kw):
    p = nt.nodes.new("ShaderNodeBsdfPrincipled"); p.location = (250, 0)
    alias = dict(color="Base Color", rough="Roughness", ior="IOR", trans=["Transmission Weight", "Transmission"],
                 coat=["Coat Weight", "Coat"], metal="Metallic", spec=["Specular IOR Level", "Specular"])
    for k, v in kw.items(): setin(p, alias.get(k, k), v)
    nt.links.new(p.outputs[0], out.inputs["Surface"])
    return p

def load_img(fname):
    path = os.path.join(TEX, fname)
    if not os.path.exists(path):
        print(f"[gin] Textur fehlt: {path} -> Etikett bleibt weiß"); return None
    return bpy.data.images.load(path, check_existing=True)

# ---------------------------------------------------------------- Reset
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras, bpy.data.collections):
    for d in list(coll): coll.remove(d)
scn = bpy.context.scene
scn.unit_settings.system = "METRIC"
col = bpy.data.collections.new("COL-gin"); scn.collection.children.link(col)
col_set = bpy.data.collections.new("COL-studio"); scn.collection.children.link(col_set)

D = DIM; R, w = D["R"], D["wall"]

# ---------------------------------------------------------------- Glas
def catmull(pts, sub=4):
    """Glatte Kurve durch alle Punkte (Catmull-Rom)."""
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        for k in range(sub):
            t = k / sub
            out.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    return out + [pts[-1]]

def offset(path, d):
    """Punkte um d nach innen versetzen (Normale aus Nachbarpunkten)."""
    res = []
    for i, (r, z) in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]; l = math.hypot(tx, tz)
        nx, nz = tz / l, -tx / l  # Außennormale
        res.append((max(0.0, r - nx * d), z - nz * d))
    return res

ri = D["rn"] - w  # Mündung innen = Korkschaft
# Außenkontur: Boden -> Standkante -> Körper -> vermessene Schulter -> Hals
shoulder = catmull([(r / 1000, z / 1000) for z, r in SHOULDER])
outer = rounded([(0.0, 0.0025, 0), (0.028, 0.0, 0.012), (R, 0.0, D["base_r"]), shoulder[0] + (0,)])
outer += shoulder[1:] + [(D["rn"], D["neck_top"] - 0.002)]
wulst = rounded([outer[-1] + (0,), (D["rn"], D["neck_top"], 0.0006), (D["rb"], D["neck_top"] + 0.0008, 0.0006),
                 (D["rb"], D["lip"], 0.0015), (ri, D["lip"], 0.0008), (ri, D["lip"] - 0.004, 0)])[1:]

def inner_wall(t, z_max=1.0):
    """Innenkontur von unten nach oben; t = Wandstärke (für den Gin etwas weniger -> Überlappung)."""
    bottom = rounded([(0.0, D["base"] + 0.0015 - (w - t), 0), (R - t, D["base"] - (w - t), 0.004),
                      (R - t, 0.02, 0)])
    side = [p for p in offset(outer, t) if 0.02 < p[1] < z_max]
    return bottom + side

inner = inner_wall(w)
glass_prof = outer + wulst + list(reversed(inner))
glass = link(bpy.data.objects.new("GEO-glass", revolve("GEO-glass", glass_prof)), col)

# Gin: innere Kontur + 0,3 mm Überlappung ins Glas (saubere Brechung an der Grenzfläche)
gin_side = inner_wall(w - 0.0003, D["fill"])
gin_prof = gin_side + [(gin_side[-1][0], D["fill"]), (0.0, D["fill"])]
gin = link(bpy.data.objects.new("GEO-gin", revolve("GEO-gin", gin_prof)), col)

# Korkschaft (in der Mündung sichtbar) + Holzkopf
cork_prof = rounded([(0, D["lip"] - 0.024, 0), (ri - 0.0001, D["lip"] - 0.024, 0.0015),
                     (ri - 0.0001, D["lip"] + 0.0005, 0), (0, D["lip"] + 0.0005, 0)])
cork = link(bpy.data.objects.new("GEO-cork", revolve("GEO-cork", cork_prof, 96)), col)
z0, ch, cr = D["lip"] + 0.0003, D["cap_h"], D["cap_r"]
cap_prof = rounded([(0, z0, 0), (cr, z0, 0.0008), (cr, z0 + ch, 0.0028), (0, z0 + ch + 0.0002, 0)])
cap = link(bpy.data.objects.new("GEO-cap", revolve("GEO-cap", cap_prof, 128)), col)

# ---------------------------------------------------------------- Etiketten
def label_mesh(name, center_angle, radius, height, zc, cols=64):
    arc = height * LABEL_ASPECT; span = arc / radius
    bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap"); grid = []
    for i in range(cols + 1):
        a = center_angle - span / 2 + span * i / cols
        x, y = radius * math.cos(a), radius * math.sin(a)
        grid.append((bm.verts.new((x, y, zc - height / 2)), bm.verts.new((x, y, zc + height / 2)), i / cols))
    for (b0, t0, u0), (b1, t1, u1) in zip(grid, grid[1:]):
        f = bm.faces.new((b0, b1, t1, t0))
        for l, (u, v) in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))): l[uv].uv = (u, v)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    sol = ob.modifiers.new("Paper", "SOLIDIFY"); sol.thickness = 0.00015; sol.offset = 1
    return ob

lab_f = link(label_mesh("GEO-label-front", -math.pi / 2, R + 0.0001, D["label_h"], D["label_z"]), col)
lab_b = link(label_mesh("GEO-label-back", math.pi / 2, R + 0.0001, D["label_h"], D["label_z"]), col)

# ---------------------------------------------------------------- Materialien
m, nt, out = new_mat("MAT-glass")
principled(nt, out, color=(0.985, 0.995, 0.99, 1), rough=0.0, ior=1.52, trans=1.0)
glass.data.materials.append(m)

m, nt, out = new_mat("MAT-gin")
principled(nt, out, color=(1, 1, 1, 1), rough=0.0, ior=1.33, trans=1.0)
gin.data.materials.append(m)

def paper_label(name, img):
    m, nt, out = new_mat(name)
    p = principled(nt, out, rough=0.7, spec=0.2)
    tc = nt.nodes.new("ShaderNodeTexCoord"); tc.location = (-900, 0)
    paper = (0.93, 0.93, 0.91, 1)
    if img:
        tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.location = (-500, 150)
        tex.interpolation = "Cubic"; tex.extension = "CLIP"
        nt.links.new(tc.outputs["UV"], tex.inputs["Vector"])
        # Rückseite des Papiers (von innen durchs Glas gesehen) = unbedrucktes Papier
        geo = nt.nodes.new("ShaderNodeNewGeometry"); geo.location = (-500, 400)
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.location = (-150, 200)
        nt.links.new(geo.outputs["Backfacing"], mix.inputs["Factor"])
        nt.links.new(tex.outputs["Color"], mix.inputs[6]); mix.inputs[7].default_value = paper
        nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    else:
        p.inputs["Base Color"].default_value = paper
    # feine Papierstruktur
    n = nt.nodes.new("ShaderNodeTexNoise"); n.location = (-500, -250)
    n.inputs["Scale"].default_value = 900; n.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.location = (-150, -250)
    bump.inputs["Strength"].default_value = 0.08; bump.inputs["Distance"].default_value = 0.0002
    nt.links.new(n.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], p.inputs["Normal"])
    return m

lab_f.data.materials.append(paper_label("MAT-label-front", load_img("label_front.png")))
lab_b.data.materials.append(paper_label("MAT-label-back", load_img("label_back.png")))

def ramp_mat(name, c1, c2, tex_type, scale, bump_s, rough):
    m, nt, out = new_mat(name)
    p = principled(nt, out, rough=rough)
    tc = nt.nodes.new("ShaderNodeTexCoord"); tc.location = (-1100, 0)
    mp = nt.nodes.new("ShaderNodeMapping"); mp.location = (-900, 0)
    mp.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    t = nt.nodes.new(tex_type); t.location = (-650, 0)
    if tex_type == "ShaderNodeTexWave":
        t.wave_type = "RINGS"; t.inputs["Scale"].default_value = 1.2
        t.inputs["Distortion"].default_value = 6; t.inputs["Detail"].default_value = 4
    else:
        t.inputs["Scale"].default_value = 1; t.inputs["Detail"].default_value = 12
        setin(t, "Roughness", 0.75)
    nt.links.new(mp.outputs[0], t.inputs["Vector"])
    cr_ = nt.nodes.new("ShaderNodeValToRGB"); cr_.location = (-400, 100)
    cr_.color_ramp.elements[0].color = c1; cr_.color_ramp.elements[1].color = c2
    fac = t.outputs["Fac"] if "Fac" in t.outputs else t.outputs[0]
    nt.links.new(fac, cr_.inputs["Fac"]); nt.links.new(cr_.outputs["Color"], p.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.location = (-150, -200)
    bump.inputs["Strength"].default_value = bump_s; bump.inputs["Distance"].default_value = 0.0005
    nt.links.new(fac, bump.inputs["Height"]); nt.links.new(bump.outputs[0], p.inputs["Normal"])
    return m

# helles Eschen-/Buchenholz, Maserung liegt quer über die Kappe
cap.data.materials.append(ramp_mat("MAT-wood", (0.80, 0.64, 0.42, 1), (0.66, 0.49, 0.30, 1),
                                   "ShaderNodeTexWave", (60, 400, 60), 0.15, 0.55))
cork.data.materials.append(ramp_mat("MAT-cork", (0.42, 0.29, 0.17, 1), (0.66, 0.52, 0.36, 1),
                                    "ShaderNodeTexNoise", (900, 900, 900), 0.6, 0.85))

# ---------------------------------------------------------------- Studio
def plane(name, size, loc, rot, mat):
    me = bpy.data.meshes.new(name)
    s = size
    me.from_pydata([(-s[0], -s[1], 0), (s[0], -s[1], 0), (s[0], s[1], 0), (-s[0], s[1], 0)], [], [(0, 1, 2, 3)])
    ob = link(bpy.data.objects.new(name, me), col_set)
    ob.location, ob.rotation_euler = loc, rot
    me.materials.append(mat); return ob

def emit_mat(name, color, strength):
    m, nt, out = new_mat(name)
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs["Color"].default_value = color
    e.inputs["Strength"].default_value = strength; nt.links.new(e.outputs[0], out.inputs["Surface"])
    return m

# Boden: für die Kamera reines Weiß (kein Horizont), für Glas und Licht ein weißer Diffus-Boden
m_floor, nt, out = new_mat("MAT-floor")
p = principled(nt, out, color=(0.9, 0.9, 0.9, 1), rough=0.8)
e = nt.nodes.new("ShaderNodeEmission"); e.inputs["Strength"].default_value = 1.0
lp = nt.nodes.new("ShaderNodeLightPath"); mx = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
nt.links.new(p.outputs[0], mx.inputs[1]); nt.links.new(e.outputs[0], mx.inputs[2])
nt.links.new(mx.outputs[0], out.inputs["Surface"])
m_black, nt, out = new_mat("MAT-flag"); principled(nt, out, color=(0, 0, 0, 1), rough=1.0, spec=0.0)
plane("GEO-floor", (1.5, 1.5), (0, 0, 0), (0, 0, 0), m_floor)
# Hintergrund nur so groß wie das Bildfeld: der Gin-"Linseneffekt" sieht daneben ins Dunkle -> Grauwerte im Glas
plane("GEO-backdrop", (0.32, 0.3), (0, 0.9, 0.28), (math.radians(90), 0, 0), emit_mat("MAT-backdrop", (1, 1, 1, 1), 1.0))
# schwarze Flags links/rechts -> definierte dunkle Glaskanten
for sx in (-1, 1):
    plane(f"GEO-flag-{'L' if sx < 0 else 'R'}", (0.3, 0.3), (sx * 0.3, 0.15, 0.25),
          (math.radians(90), 0, math.radians(90)), m_black)
world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); scn.world = world
if hasattr(world, "use_nodes"):
    try: world.use_nodes = True
    except Exception: pass
bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
if bg: bg.inputs["Color"].default_value = (0.35, 0.35, 0.35, 1); bg.inputs["Strength"].default_value = 0.15

def area(name, loc, rot, size, power, shape="RECTANGLE", size_y=None):
    ld = bpy.data.lights.new(name, "AREA"); ld.energy = power; ld.shape = shape
    ld.size = size; ld.size_y = size_y or size
    ob = link(bpy.data.objects.new(name, ld), col_set)
    ob.location = loc; ob.rotation_euler = rot; return ob

def aim(ob, target=(0, 0, 0.1)):
    from mathutils import Vector
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat("-Z", "Y").to_euler()

# zwei Strip-Softboxen seitlich vorn = vertikale Glanzkanten, Top für Korken/Schulter
for name, loc in (("LGT-strip-L", (-0.45, -0.35, 0.18)), ("LGT-strip-R", (0.45, -0.35, 0.18))):
    aim(area(name, loc, (0, 0, 0), 0.12, 4, size_y=0.9))
aim(area("LGT-top", (0, -0.05, 0.9), (0, 0, 0), 0.8, 6, "DISK"))
aim(area("LGT-front-fill", (0, -1.2, 0.25), (0, 0, 0), 1.0, 2), (0, 0, 0.08))

# ---------------------------------------------------------------- Kamera
cam_d = bpy.data.cameras.new("CAM-hero"); cam_d.lens = 85
cam = link(bpy.data.objects.new("CAM-hero", cam_d), col_set)
cam.location = (0, -0.575, 0.13); aim(cam, (0, 0, 0.1085))
scn.camera = cam

# ---------------------------------------------------------------- Render
scn.render.engine = "CYCLES"
cy = scn.cycles
cy.samples = 256; cy.use_denoising = True
cy.max_bounces = 32; cy.transmission_bounces = 32; cy.glossy_bounces = 16
cy.transparent_max_bounces = 16; cy.caustics_reflective = False; cy.caustics_refractive = False
cy.blur_glossy = 0.5
scn.render.resolution_x, scn.render.resolution_y = 1500, 2000
scn.render.resolution_percentage = 100
scn.view_settings.view_transform = "Standard"  # Markenfarben 1:1, weißer Hintergrund bleibt weiß
scn.view_settings.look = "None"
scn.render.image_settings.file_format = "PNG"

# ---------------------------------------------------------------- CLI
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(flag, default=None):
    return argv[argv.index(flag) + 1] if flag in argv else default
if arg("--samples"): cy.samples = int(arg("--samples"))
if arg("--res"):
    x, y = arg("--res").lower().split("x"); scn.render.resolution_x, scn.render.resolution_y = int(x), int(y)
if arg("--save"): bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(arg("--save")))
if arg("--render"):
    scn.render.filepath = os.path.abspath(arg("--render"))
    bpy.ops.render.render(write_still=True)
print("[gin] fertig")
