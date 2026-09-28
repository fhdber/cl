"""
WRAP Gin – Szenenbilder (Blender 5.x, Cycles). Baut die Flasche aus gin_bottle.py und stellt sie in eine Szene.

  blender -b -P scenes.py -- --scene pink  --render pink.png
  blender -b -P scenes.py -- --scene all   --outdir renders/ [--samples 192] [--res 1200x1500]

Szenen
  pink   Hard Light:      Markenpink, harte Sonne, schwarzer Sockel, langer grafischer Schatten
  noir   Film Noir:       schwarzes Studio, Spiegelboden, Spot von oben, Rim-Licht in Pink
  stone  Botanicals:      Travertin-Blöcke, Grapefruit, Wacholder, Jalousie-Schatten
  set    It's a Wrap:     Filmset – Apple Box, Gaffer-X als Marke, Pink-Gel von hinten
"""
import bpy, bmesh, math, os, sys, runpy, random
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(flag, default=None):
    return argv[argv.index(flag) + 1] if flag in argv else default

# ---------------------------------------------------------------- Flasche bauen (ohne Render)
_argv = sys.argv; sys.argv = [sys.argv[0]]
G = runpy.run_path(os.path.join(HERE, "gin_bottle.py"), run_name="gin_bottle")
sys.argv = _argv
new_mat, principled, area, aim, setin = G["new_mat"], G["principled"], G["area"], G["aim"], G["setin"]
scn = bpy.context.scene
col_set = bpy.data.collections["COL-studio"]
BOTTLE = [o for o in bpy.data.collections["COL-gin"].objects]
PINK_HEX, BLACK_HEX = "E4246E", "161616"

def lin(hexstr, a=1.0):
    c = [int(hexstr[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (a,)

PINK, BLACK = lin(PINK_HEX), lin(BLACK_HEX)

# Glas/Gin: Schattenstrahlen teilweise durchlassen -> heller, glasiger Schatten statt Vollschwarz
def glass_shadow(name, keep=0.25):
    m = bpy.data.materials[name]; nt = m.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    bsdf = out.inputs["Surface"].links[0].from_node
    lp = nt.nodes.new("ShaderNodeLightPath"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mx = nt.nodes.new("ShaderNodeMixShader"); mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"; mul.inputs[1].default_value = 1 - keep
    nt.links.new(lp.outputs["Is Shadow Ray"], mul.inputs[0]); nt.links.new(mul.outputs[0], mx.inputs[0])
    nt.links.new(bsdf.outputs[0], mx.inputs[1]); nt.links.new(tr.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs["Surface"])

glass_shadow("MAT-glass"); glass_shadow("MAT-gin")

# ---------------------------------------------------------------- Studio leeren, Flasche an einen Controller hängen
for o in list(col_set.objects):
    if o.type != "CAMERA": bpy.data.objects.remove(o, do_unlink=True)
cam = bpy.data.objects["CAM-hero"]
ctl = bpy.data.objects.new("CTL-bottle", None); col_set.objects.link(ctl)
for o in BOTTLE: o.parent = ctl

# ---------------------------------------------------------------- Bausteine
def obj(name, me, mat=None):
    ob = bpy.data.objects.new(name, me); col_set.objects.link(ob)
    if mat: me.materials.append(mat)
    return ob

def mat_simple(name, color, rough=0.5, **kw):
    m, nt, out = new_mat(name); principled(nt, out, color=color, rough=rough, **kw); return m

def cove(name, mat, y_wall=0.6, radius=0.35, height=2.5, depth=3.0, width=5.0):
    """Hohlkehle: Boden + gerundeter Übergang + Wand (nahtloser Studiohintergrund)."""
    prof = [(-depth, 0.0)] + [(y_wall - radius + radius * math.sin(a), radius - radius * math.cos(a))
                              for a in [i / 16 * math.pi / 2 for i in range(17)]] + [(y_wall, height)]
    verts = [(x, y, z) for (y, z) in prof for x in (-width / 2, width / 2)]
    faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(prof) - 1)]
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.shade_smooth()
    return obj(name, me, mat)

def box(name, size, loc, mat, bevel=0.002):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.active_object; ob.name = name; ob.scale = size
    for c in ob.users_collection: c.objects.unlink(ob)
    col_set.objects.link(ob)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        b = ob.modifiers.new("Bevel", "BEVEL"); b.width = bevel; b.segments = 3
    ob.data.materials.append(mat); return ob

def cylinder(name, r, h, loc, mat, bevel=0.002, verts=128):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(loc[0], loc[1], loc[2] + h / 2))
    ob = bpy.context.active_object; ob.name = name
    for c in ob.users_collection: c.objects.unlink(ob)
    col_set.objects.link(ob)
    if bevel:
        b = ob.modifiers.new("Bevel", "BEVEL"); b.width = bevel; b.segments = 3; b.limit_method = "ANGLE"
    for p in ob.data.polygons: p.use_smooth = True
    ob.data.materials.append(mat); return ob

def light(name, kind, loc, target, power, size=0.1, color=(1, 1, 1), **kw):
    ld = bpy.data.lights.new(name, kind); ld.energy = power; ld.color = color
    if kind == "AREA": ld.size = size; ld.size_y = kw.get("size_y", size); ld.shape = kw.get("shape", "RECTANGLE")
    if kind in ("POINT", "SPOT"): ld.shadow_soft_size = size
    if kind == "SPOT": ld.spot_size = math.radians(kw.get("cone", 30)); ld.spot_blend = kw.get("blend", 0.3)
    if kind == "SUN": ld.angle = math.radians(kw.get("angle", 0.5))
    ob = bpy.data.objects.new(name, ld); col_set.objects.link(ob); ob.location = loc
    aim(ob, target); return ob

def world(color, strength):
    w = scn.world; bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = color; bg.inputs["Strength"].default_value = strength

def camera(loc, target, lens=85, fstop=None, focus=None):
    cam.location = loc; aim(cam, target); cam.data.lens = lens
    cam.data.dof.use_dof = fstop is not None
    if fstop:
        cam.data.dof.aperture_fstop = fstop
        cam.data.dof.focus_distance = (Vector(focus or target) - Vector(loc)).length

def place_bottle(z=0.0, x=0.0, y=0.0, rot_deg=0.0):
    ctl.location = (x, y, z); ctl.rotation_euler = (0, 0, math.radians(rot_deg))

# ---------------------------------------------------------------- Szenen
def scene_pink():
    """Markenpink als Raum, eine harte Sonne, der Schatten ist die zweite Form im Bild."""
    cove("GEO-cove", mat_simple("MAT-pink", PINK, 0.85), y_wall=0.35, radius=0.12)
    cylinder("GEO-plinth", 0.075, 0.07, (0, 0, 0), mat_simple("MAT-plinth", BLACK, 0.6), bevel=0.0015)
    place_bottle(z=0.07)
    light("LGT-sun", "SUN", (-1.2, -0.55, 0.62), (0, 0, 0.1), 4.2, angle=0.4)
    light("LGT-strip", "AREA", (0.5, -0.45, 0.25), (0, 0, 0.17), 3, 0.08, size_y=0.8)
    world(PINK, 0.25)
    camera((0, -0.92, 0.26), (0.055, 0, 0.17))

def scene_noir():
    """Schwarzer Raum, Spiegelboden, ein Spot von oben, Glaskanten aus zwei Strips – rechts in Pink."""
    floor = mat_simple("MAT-floor-gloss", (0.004, 0.004, 0.004, 1), 0.06)
    me = bpy.data.meshes.new("GEO-floor"); me.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
    obj("GEO-floor", me, floor)
    place_bottle(z=0.0)
    light("LGT-spot", "SPOT", (0, 0.05, 0.75), (0, 0, 0.05), 45, 0.02, cone=22, blend=0.6)
    light("LGT-rim-L", "AREA", (-0.32, 0.28, 0.12), (0, 0, 0.1), 6, 0.05, size_y=0.6)
    light("LGT-rim-R", "AREA", (0.32, 0.28, 0.12), (0, 0, 0.1), 10, 0.05, color=PINK[:3], size_y=0.6)
    light("LGT-label", "AREA", (0.15, -0.8, 0.15), (0, 0, 0.07), 0.45, 0.3)
    world((0, 0, 0, 1), 0)
    camera((0, -0.7, 0.07), (0, 0, 0.1))

def travertine():
    m, nt, out = new_mat("MAT-travertine")
    p = principled(nt, out, rough=0.72)
    tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (6, 6, 28)  # liegende Schichtung
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 3; n.inputs["Detail"].default_value = 10
    nt.links.new(mp.outputs[0], n.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = lin("CDBBA0"); ramp.color_ramp.elements[1].color = lin("E6DAC6")
    nt.links.new(n.outputs["Fac"], ramp.inputs["Fac"]); nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    vo = nt.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 260
    nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
    pores = nt.nodes.new("ShaderNodeMapRange"); pores.inputs["From Min"].default_value = 0.0
    pores.inputs["From Max"].default_value = 0.08
    nt.links.new(vo.outputs["Distance"], pores.inputs["Value"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.0006
    nt.links.new(pores.outputs["Result"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], p.inputs["Normal"])
    return m

def grapefruit(loc, r=0.048):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=96, v_segments=48, radius=r)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_outer=True)
    edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    cap = bmesh.ops.edgeloop_fill(bm, edges=edges)["faces"]
    for f in bm.faces: f.smooth = True
    for f in cap: f.material_index = 1; f.smooth = False
    me = bpy.data.meshes.new("GEO-grapefruit"); bm.to_mesh(me); bm.free()
    ob = obj("GEO-grapefruit", me)
    rind = mat_simple("MAT-rind", lin("F2B24A"), 0.45, coat=0.3)
    m, nt, out = new_mat("MAT-flesh")
    p = principled(nt, out, rough=0.25, coat=0.6)
    setin(p, ["Subsurface Weight", "Subsurface"], 0.4); setin(p, "Subsurface Radius", (0.004, 0.001, 0.0008))
    tc = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient"); grad.gradient_type = "RADIAL"
    nt.links.new(tc.outputs["Object"], grad.inputs["Vector"])
    seg = nt.nodes.new("ShaderNodeMath"); seg.operation = "MULTIPLY"; seg.inputs[1].default_value = 12
    fr = nt.nodes.new("ShaderNodeMath"); fr.operation = "FRACT"
    nt.links.new(grad.outputs["Fac"], seg.inputs[0]); nt.links.new(seg.outputs[0], fr.inputs[0])
    tri = nt.nodes.new("ShaderNodeMath"); tri.operation = "PINGPONG"; tri.inputs[1].default_value = 0.5
    nt.links.new(fr.outputs[0], tri.inputs[0])
    sph = nt.nodes.new("ShaderNodeTexGradient"); sph.gradient_type = "SPHERICAL"
    mp = nt.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1 / r, 1 / r, 1 / r)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"]); nt.links.new(mp.outputs[0], sph.inputs["Vector"])
    # Membranen (Segmentlinien) + heller Rand/Albedo
    memb = nt.nodes.new("ShaderNodeMapRange"); memb.inputs["From Min"].default_value = 0.0
    memb.inputs["From Max"].default_value = 0.05
    nt.links.new(tri.outputs[0], memb.inputs["Value"])
    rim = nt.nodes.new("ShaderNodeMapRange"); rim.inputs["From Min"].default_value = 0.08
    rim.inputs["From Max"].default_value = 0.14
    nt.links.new(sph.outputs["Fac"], rim.inputs["Value"])
    mask = nt.nodes.new("ShaderNodeMath"); mask.operation = "MULTIPLY"
    nt.links.new(memb.outputs[0], mask.inputs[0]); nt.links.new(rim.outputs[0], mask.inputs[1])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    mix.inputs[6].default_value = lin("F4E3C8"); mix.inputs[7].default_value = lin("E8504F")
    nt.links.new(mask.outputs[0], mix.inputs["Factor"]); nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    vo = nt.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 900
    nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.5
    bump.inputs["Distance"].default_value = 0.0004
    nt.links.new(vo.outputs["Distance"], bump.inputs["Height"]); nt.links.new(bump.outputs[0], p.inputs["Normal"])
    me.materials.append(rind); me.materials.append(m)
    ob.location = loc; ob.rotation_euler = (math.radians(58), 0, math.radians(-15))
    return ob

def scene_stone():
    """Warmes Off-White, gestapelter Travertin, Botanicals aus dem Rezept, Jalousie-Licht."""
    cove("GEO-cove", mat_simple("MAT-sand", lin("E9E1D4"), 0.9), y_wall=0.45, radius=0.15)
    trav = travertine()
    box("GEO-block-low", (0.34, 0.2, 0.05), (-0.03, 0.02, 0.025), trav, 0.003)
    box("GEO-block-high", (0.14, 0.14, 0.11), (0.06, 0.06, 0.05 + 0.055), trav, 0.003)
    place_bottle(z=0.16, x=0.06, y=0.06)
    grapefruit((-0.105, -0.02, 0.05 + 0.03))
    berry = mat_simple("MAT-juniper", lin("2B2F4A"), 0.55, coat=0.2)
    random.seed(7)
    for i in range(9):
        a = random.uniform(-0.6, 1.4); d = random.uniform(0.07, 0.1)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=random.uniform(0.0038, 0.0048),
                                                             location=(-0.105 + d * math.cos(a), -0.035 - abs(d * math.sin(a)) * 0.5, 0.0544))
        b = bpy.context.active_object; b.name = f"GEO-juniper-{i}"
        for c in b.users_collection: c.objects.unlink(b)
        col_set.objects.link(b); b.data.materials.append(berry)
        for p in b.data.polygons: p.use_smooth = True
    sun_pos = Vector((-1.0, -0.55, 0.85))
    light("LGT-sun", "SUN", sun_pos, (0, 0, 0.1), 3.2, angle=1.2, color=(1, 0.93, 0.84))
    # Jalousie: Lamellen zwischen Sonne und Set, für die Kamera unsichtbar
    blinds = bpy.data.objects.new("CTL-blinds", None); col_set.objects.link(blinds)
    blinds.location = sun_pos.normalized() * 0.7 + Vector((0, 0.1, 0.12)); aim(blinds, (0, 0.1, 0.12))
    slat = mat_simple("MAT-slat", (0.1, 0.1, 0.1, 1), 1)
    for i in range(-14, 15):
        me = bpy.data.meshes.new(f"GEO-slat-{i}")
        me.from_pydata([(-0.8, -0.011, 0), (0.8, -0.011, 0), (0.8, 0.011, 0), (-0.8, 0.011, 0)], [], [(0, 1, 2, 3)])
        s = obj(f"GEO-slat-{i}", me, slat); s.parent = blinds; s.location = (0, i * 0.035, 0)
        s.rotation_euler = (math.radians(20), 0, math.radians(8))
        s.visible_camera = False; s.visible_glossy = False; s.visible_transmission = False
    light("LGT-fill", "AREA", (0.6, -0.8, 0.4), (0, 0, 0.1), 12, 1.2)
    world(lin("E9E1D4"), 0.25)
    camera((0.12, -1.12, 0.3), (-0.01, 0.02, 0.19), lens=85, fstop=8, focus=(0.06, 0.02, 0.24))

def apple_box(loc, mat):
    """Half Apple (12 x 20 x 4 Zoll) mit Griffmulden."""
    ob = box("GEO-applebox", (0.508, 0.305, 0.102), (loc[0], loc[1], loc[2] + 0.051), mat, 0.004)
    for i, sx in enumerate((-1, 1)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.018, depth=0.4, location=(0, 0, 0))
        cut = bpy.context.active_object; cut.name = f"CUT-hand-{i}"
        cut.scale = (2.4, 1, 1); cut.rotation_euler = (math.radians(90), 0, 0)
        cut.location = (loc[0] + sx * 0.16, loc[1], loc[2] + 0.052)
        cut.hide_render = True; cut.display_type = "WIRE"
        m = ob.modifiers.new(f"Hand-{i}", "BOOLEAN"); m.object = cut; m.operation = "DIFFERENCE"
        ob.modifiers.move(len(ob.modifiers) - 1, 0)
    return ob

def plywood():
    m, nt, out = new_mat("MAT-plywood"); p = principled(nt, out, rough=0.62)
    tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.5, 30, 30); nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    w = nt.nodes.new("ShaderNodeTexWave"); w.inputs["Scale"].default_value = 1; w.inputs["Distortion"].default_value = 2.5
    w.inputs["Detail"].default_value = 5; nt.links.new(mp.outputs[0], w.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = lin("B98D5C"); ramp.color_ramp.elements[1].color = lin("D9B485")
    nt.links.new(w.outputs["Fac"], ramp.inputs["Fac"]); nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    return m

def scene_set():
    """Filmset nach Drehschluss: Bottle auf der Apple Box, Gaffer-X als Marke, Pink-Gel von hinten."""
    cove("GEO-cove", mat_simple("MAT-studio-grey", lin("2A2A2A"), 0.8), y_wall=0.7, radius=0.3)
    apple_box((0, 0.02, 0), plywood())
    place_bottle(z=0.102, x=0.07, y=0.0, rot_deg=-8)
    tape = mat_simple("MAT-tape", PINK, 0.7)
    for i, a in enumerate((35, -35)):
        t = box(f"GEO-tape-{i}", (0.07, 0.012, 0.0006), (-0.04, -0.075, 0.1023 + i * 0.0005), tape, 0)
        t.rotation_euler = (0, 0, math.radians(a))
    light("LGT-key", "SPOT", (-0.9, -0.7, 0.9), (0.05, 0, 0.18), 260, 0.03, cone=18, blend=0.25, color=(1, 0.95, 0.88))
    light("LGT-gel", "AREA", (0.55, 0.55, 0.35), (0.07, 0, 0.2), 30, 0.25, color=PINK[:3])
    light("LGT-fill", "AREA", (0.3, -1.2, 0.3), (0, 0, 0.15), 6, 1.0)
    world((0.02, 0.02, 0.02, 1), 0.3)
    camera((0.05, -0.82, 0.24), (0.06, 0, 0.2), lens=85)

SCENES = dict(pink=scene_pink, noir=scene_noir, stone=scene_stone, set=scene_set)

# ---------------------------------------------------------------- Render
def build_and_render(name, path=None):
    SCENES[name]()
    scn.render.resolution_x, scn.render.resolution_y = 1200, 1500
    if arg("--res"):
        x, y = arg("--res").lower().split("x"); scn.render.resolution_x, scn.render.resolution_y = int(x), int(y)
    scn.cycles.samples = int(arg("--samples", 192))
    if path:
        scn.render.filepath = os.path.abspath(path); bpy.ops.render.render(write_still=True)

names = list(SCENES) if arg("--scene", "pink") == "all" else [arg("--scene", "pink")]
if len(names) == 1:
    build_and_render(names[0], arg("--render"))
    if arg("--save"): bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(arg("--save")))
else:
    # jede Szene in einem frischen Prozess-Zustand: Skript pro Szene neu aufrufen
    import subprocess
    outdir = arg("--outdir", "renders"); os.makedirs(outdir, exist_ok=True)
    extra = [a for a in argv if a not in ("--scene", "all", "--outdir", outdir)]
    exe = [bpy.app.binary_path, "-b", "-P"] if bpy.app.binary_path else [sys.executable]
    for n in names:
        subprocess.run([*exe, os.path.abspath(__file__), "--", "--scene", n,
                        "--render", os.path.join(outdir, f"wrap_{n}.png"), *extra], check=True)
