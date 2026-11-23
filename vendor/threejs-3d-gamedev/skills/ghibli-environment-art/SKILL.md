---
name: ghibli-environment-art
description: "Studio Ghibli / Kazuo Oga 3D environment styling, tree-size-driven domain-warped cel-shaded canopies, shingled anti-polyp foliage brushwork, camera-turn-invariant billboards, wind shaders, dappled shadows, water, and clouds in Three.js."
---

# Kazuo Oga & Studio Ghibli 3D Environmental Art Skill

This skill codifies the environmental art direction of **Kazuo Oga** (Studio Ghibli's master background art director on *My Neighbor Totoro*, *Princess Mononoke*, *Only Yesterday*, and *Spirited Away*) translated into real-time **Three.js / GLSL shaders and procedural geometry**.

Use this skill as the single source of truth whenever building or refining natural worlds so every element—trees, terrain, country paths, rivers, snow, sky, and architecture—shares one cohesive, hand-painted Studio Ghibli aesthetic.

---

## 1. Core Philosophy: Kazuo Oga's Nicker Poster Colour Method

1. **Opaque Matte Gouache Layers (Not Plastic PBR or Blurry Airbrush)**
   - Oga paints with **Nicker Poster Colour** (opaque, matte Japanese gouache) on dampened Muse TMK poster paper.
   - **Wet-on-Wet Base, Crisp Stepped Foregrounds**: Distant skies, mist, and broad meadow washes blend softly, while foreground transitions (grass meeting dirt, snow lips, leaf clusters, water foam) use **crisp, noise-perturbed poster-color steps** (`smoothstep` over tight world-space FBM bands), never wide, blurry alpha gradients.
2. **Warm Sunlight vs. Cool Lavender-Teal Shadows**
   - Sunlit surfaces are infused with warm cream-amber (`#fffbf0`), while shadows never go dead black or muddy grey—they shift toward **cool cerulean, emerald-teal, or periwinkle-violet** (`#9286b8` / `#1d4e44`), reflecting ambient sky light.
3. **"Implication and Impression" Over Wall-to-Wall Procedural Tiling**
   - Never tile uniform procedural patterns (such as wall-to-wall Voronoi cobblestones or repetitive noise grids) across a surface.
   - Paint broad, calm gouache washes first, then flick **sparse, intentional details** (~5–8% coverage: a few warm pebbles, an intermittent patch of center clover, occasional exposed stones) so the eye completes the texture naturally.
4. **Botanical & Geological Specificity**
   - Nature is asymmetric, weathered, and alive. Trees lean slightly, roots grip the earth, paths meander in long S-curves with worn wheel ruts, riverbanks transition through moist moss and wet alluvial shingle, and snow obeys altitude and gravity.

---

## 2. Trees, Forests & Foliage (The Living Canopy)

Our procedural Ghibli forest combines **3D hierarchical branch skeletons** (`@dgreenheck/ez-tree`) with **connected `L0->L1` summer fork trunks**, **3-tier real botanical multi-sprig foliage bouquets** (`paintGhibliFoliageBouquet`), **tree-size-driven domain-warped 4-band gouache + crevice/tip glazing**, **camera-turn-invariant viewpoint billboards**, and **world-space traveling wind waves**.

### 2.1 Tree-Size-Driven, Domain-Warped 4-Band Gouache & Leaf Crevice/Tip Glazing (Zero "Bubble Wrap", Zero Flat Camo Blobs)
- **Anti-Patterns That Cause "Bubble Wrap" or Flat "Camo Blobs" (Never Do These)**:
  1. Never weight deciduous sprite lighting heavily by per-card/per-sub-bough spherical normals (`boughSubDir`) or multiply raw luminance diagonally over the whole quad after cel quantization, which outlines every overlapping quad as an individual blister ("bubble wrap").
  2. Conversely, never flatten cel bands completely without per-leaf internal contrast or crevice modulation — 3D billboard clouds become unreadable blobs of flat green/pink color instead of botanical trees.
  3. Never apply a high-frequency (`lobeFreq >= 5.0`), unwarped periodic sine grid normalized identically across tiny bushes and giant trees.
- **Continuous Crown-Space Lighting, Pre-Band Leaf Detail & Post-Band Crevice/Tip Glazing**:
  - Evaluate deciduous canopy normals in continuous 3D world crown space (`mainCrownDir` blended with analytical gradient `macroGrad` of a domain-warped field) with calm `macroBillow`/`secBillow` (`hollowAO` under `#ifdef IS_DECIDUOUS_FOLIAGE`).
  - Boost **pre-band botanical `leafDetail`** (`clamp((texLum - 0.50) * 1.45, -0.48, 0.48) * max(vCrownTerms.w, 0.34)`) before 4-band threshold selection so interior leaves break across illumination steps naturally.
  - Apply subtle **post-band Kazuo Oga botanical crevice & tip glazes** (`deepCrevice` darkening deep leaf pockets toward `vBand3 * 0.86`, and `leafTipGlow` warming outer sunlit leaf tips toward `min(1.12, vBand0 * vec3(1.07, 1.06, 0.92))`), preserving cohesive cel masses while giving every cluster crisp painted leaf separation.
  - Randomize 3D azimuth orientation (`rotAz`), triaxial anisotropy (`anisoScale`), key-light elevation/azimuth jitter, and band-center bias per tree instance so neighboring trees never share repeating patterns.
- **Explicit Scaling With Tree Size (`worldHeightM`)**:
  - Compute `sizeFactor = clamp((worldHeightM - 3.6) / 11.2, 0.0, 1.0)` from true world height (`uSpanY * instScale * modelScale`):
    - **Small shrubs & saplings (`~2.5–4.5m`, `sizeFactor ~ 0`)**: `macroFreq ~ 1.22`, `secWeight = 0` — renders **1–2 calm, bold, graphic gouache shapes**.
    - **Mature woodland trees (`~8–11m`, `sizeFactor ~ 0.5`)**: `macroFreq ~ 1.9–2.2` with strong domain warp — renders **2–4 sweeping, asymmetric canopy billows**.
    - **Giant emergent mother trees (`~14–18m`, `sizeFactor ~ 1.0`)**: `macroFreq ~ 2.95` + secondary overhang shelf octave (`secWeight -> 1.2`) — unfolds **grand, multi-tiered *Totoro*-style camphor/mother-oak domes** with stepped overhang shadow pockets.
- **Harmonized 4-Band Nicker Poster Colour Palette & Band Proportions**:
  - Balance thresholds (`baseCenter`, extended lower viridian shelf) so **Band 1 (lush mid-leaf green / sakura rose)** is the dominant body (~35–43%), **Band 0 (warm sunlit chartreuse / ivory blush)** crowns the upper sun-kissed crests (~21–25%), **Band 2 (cool emerald-viridian / orchid)** forms generous stepped bough shelves (~20–21%), and **Band 3 (deep cerulean-teal / wisteria)** tucks into deep interior recesses (~15–21%).

### 2.2 Botanical Multi-Sprig Bouquets & Shaded Core Seal (Anti-"肉瘤" / Anti-Blob Doctrine)
- **Root Causes of "肉瘤" (Cauliflower Blobs) & Blurry Mud (Never Do These)**:
  1. Never draw bulbous club leaves (`pinched neck, bulging tip`) radially fanned `90°` around an ellipse, and never threshold box-blurred alpha (`bA < 0.28`) — they fuse into swollen cauliflower polyps along the sky edge.
  2. Never paint coarse cloudy ovals in the center of a billboard without real serrated/lobed botanical silhouettes, and never leave sparse internal alpha pinholes inside the core where post-process outlines spawn noisy ink dots.
- **3-Tier Botanical `leafImg` Bouquet (`paintGhibliFoliageBouquet`)**:
  - Compose each broadleaf texture tile (`1024×1024`, placed into atlas slot `(1024, 0)` with `putImageData` so luminance contrasts stay exact) from **`29` cropped real botanical sprigs** (`oak.png` at `0.84`, `aspen.png` / `ash.png` at `0.78`) arranged across **inner base cushion, mid leaf ring, and outer perimeter sprig tips** (~37% outer quad fill, crisp natural oak/birch silhouettes with deep air pockets at the rim).
  - **Seal Central Bough Core (`coreDist < 0.85`)**: Inside the elliptic center (`coreDist = Math.hypot((x - 512) / 230, (y - 512) / 195) < 0.85`, covering `~0.16–0.19 × cardSize` around card center), floor alpha (`Math.max(aAvg, 0.56 * (1.0 - coreDist * 0.25))`, ramping `[0.34..0.48] -> 0..255`) and seed empty pinhole pixels with dark forest interior (`rgb = (52, 82, 46)`) so overlapping cards form solid shaded bough undersides, harbor **zero** internal outline noise, and completely veil buried branch tips.
  - **Crisp Boundary Fade & Luminance Contrast Normalization**: Fade outer card margins smoothly across `18..38px` (`wx * wy`) to avoid hard box seams or halo fringes, and normalize sprig luminance around median `0.50` clamped to `[0.22..0.84]` before `putImageData(..., 1024, 0)` so pre-band `leafDetail` and post-band crevice/tip glazes read clearly at close and mid range.

### 2.3 Connected `L0->L1` Branch Architecture, Camera-Turn Invariance & 60 FPS LOD Budget
- **Visible Connected Trunks + Buried `L1` Forks (`summerBark` + `coreCushions`)**:
  - Never bury an entire deciduous canopy inside low flat puffs that hide the trunk/fork structure (which reads as a floating bush/blob), and never let thin `L1` twigs extend out into the lacy outer sprig rim (`~37%` quad fill) where bare brown Y-stubs poke through when viewed from low ground angles.
  - Note also on verification (`OrbitControls` camera testing): `audit_trees.mjs` must sweep **dozens of RNG seeds** (`options.seed`, keeping `targetHeight` fixed at `2.6`), never just one seed, and `worldStudio.flyTo` takes `durationMs: 0` with `position.y > target.y` to prevent `OrbitControls` `maxPolarAngle` clamping during low upward-looking checks.
  - Emit **connected `L0` trunk (`taperStart = 0.56`, `taperEnd = 0.72`)** plus **primary `L1` forks (`maxStartFrac = 0.72`, `contScale 0.42..0.54`, `forkTilt 0.48..0.64`, `taperStart = 0.16`, `taperEnd = 0.30`; hide `L1` at `lodTier >= 2`)**.
  - Anchor mandatory **`coreCushions`** directly onto every `L1` and `L0` tip (`lerp(..., 0.08)`, `forceAccept = true`), bridge the upper crown dome (`fullCap = 30/28/15`, `_puffScale = 1.16` LOD1 / `1.34` LOD2), and apply sub-bough cohesion clamping (`lerp 0.24`, `maxSubDist 0.72`) so strong structural forks visibly enter shaded bough undersides with ~0 exposed bark tips.
- **Viewpoint-Cylindrical Billboards (`0.00000000m` Camera-Turn Delta)**:
  - Never orient deciduous canopy cards using `viewMatrix` (`camRight`, `camUp`, `camFwd`), which rotates every leaf card in world space when panning or tilting the camera (`yaw`/`pitch`), causing leaves and cel bands to swim during a pure camera turn.
  - Build the orthonormal puff basis strictly from **`toCamRaw = cameraPosition - crownWorldCenter`** with upright botanical splay (`±30°` + horizontal flip), making pure camera look rotations **100% invariant** (`0.00000000m`) at every distance.
- **Positive Forward Hemisphere Depth**:
  - Keep `capBulgeZ` strictly positive (`+0.08..+0.36 * worldCardSize` toward `cameraPosition`) and share identical macro `totalWind` between bark and foliage.
- **Extended Hysteresis Valley LOD Envelope (~60 FPS Budget)**:
  - Keep foreground & cottage valley sectors (`effDistXZ <= 56..74m`, `18m` hysteresis) locked on `_hiGeo`, midground hillsides (`<= 98..120m`, `22m` hysteresis) on `_midGeo`, and distant mountain ridges (`> 120m`) on `_farGeo` so `OrbitControls` turns never pop leaf density in front of the viewer while holding Cottage/Forest views at **60 FPS**.
- **Outer-Silhouette-Only `Anime Cel` Outlines (`alpha = 0.96`)**:
  - Output `gl_FragColor.a = 0.96` on foliage and upper/collar bark; in `GhibliPostProcessing`, suppress internal leaf-on-leaf normal/luma edges (`!bothFoliage`) and gate foliage depth ink strictly on steep grazing-angle-compensated depth jumps so `Anime Cel` frames **only outer crown silhouettes** and lower trunks.

### 2.4 World-Space Traveling Wind Waves (Never Sync-Jerking)
- **Anti-Pattern to Avoid**: Never apply symmetric `sin(uTime)` vertical bobbing or uniform phase offsets, which make trees look like they are jerking in robotic lockstep.
- **Traveling Downwind Gust Field**:
  - Compute each tree's downwind coordinate `dot(instRoot.xz, wVec)` and sample a drifting 3D Simplex turbulence field (`simplex3`).
  - Bias bending **asymmetrically into the wind direction** (`downwindBend = (0.48 + 0.46 * gustWave) * ...`) so trees lean into gusts and relax smoothly.
  - Apply a **cantilever beam profile** (`h * h * (0.65 + 0.35 * h)`) that keeps roots pinned at `0` and curves smoothly toward the crown, with circular-arc vertical foreshortening (`cantileverDrop = -dot(branchXZ, branchXZ) / (2.5 * worldHeight)`) so bending limbs dip slightly rather than stretching upward.
  - Anchor high-frequency 3-octave Simplex leaf flutter by `uv.y` (`0` at branch stem, `1` at leaf tip) so leaves stay attached to their twigs.

### 2.5 Sun-Projected *Komorebi* (Dappled Canopy Shadows)
- Bake a world-space `DataTexture` (`uCanopyShadowTex`) projecting each tree's root contact shadow, trunk bridge, and 3 multi-lobe sub-crowns along the sun vector `(+0.52, -0.40)`.
- In the terrain and water shaders, warp `shadowUv` with wind-animated noise and add high-frequency leaf-gap dapple (`leafDapple`) stepped via `smoothstep(0.20, 0.44, rawShadow + dappleMod)` into a cool emerald-indigo shadow tint.

### 2.6 Winter Trees: Deciduous Leaf-Shedding, 3D Branch Snow & Gust Shake-Off
- **Deciduous vs. Evergreen Realism**:
  - In Winter, ~78% of deciduous trees (`oak`, `birch`, `bush`) shed 100% of their leaves (`vWinterLeafDrop`), exposing their 3D branch skeletons; ~22% retain sparse marcescent winter leaf clusters; evergreen pines keep 100% of their needles.
- **3D Branch & Bough Snow Ridges**:
  - Extrude upper branch vertices (`normal.y > -0.12`) upward to form a physical 3D snow ridge, darken the wet bark underside (`* 0.58`) for strong figure-ground contrast, and shade a crisp glacier-blue wall band (`#7aa8e6`) beneath a sunlit white snow cap.
  - On pine boughs, lower the alpha cutout threshold (`mix(0.42, 0.14, boughSnowSolid)`) so snow bridges across needles into puffy, stepped Ghibli snow pillows.
- **Wind-Gust Snow Shake-Off**:
  - When a strong gust hits, spawn falling snow-clump particles directly from elevated canopy boughs that drop under gravity with gentle downwind drift while the tree bows smoothly downwind.

### 2.7 Distant Horizon Mountain Forest LOD ("4-Crown Copse Clusters")
- **Horizon Mesh Alignment & Amphitheater Envelope**:
  - Align `horizon.glb` vertically with `TERRAIN_LIFT` (`+15.0m`), peak mountain relief in the `d = 180..540m` amphitheater ring, and suppress outer (`d > 560m`) horizon domes (`outerSuppress = 1.0 - 0.68 * smoothstep01((d - 560.0) / 420.0)`) so distant hills never poke above the treeline as bald domes.
- **2-Draw-Call 4-Crown Merged Copse Clusters (`pine_horizon_copse` & `oak_horizon_copse`)**:
  - Merge 4 offset single-billboard (`Billboard.Single`, `leaves.size: 25..26.5`) tree crowns into one shared `BufferGeometry` (~220 tris per 4-tree cluster) and spawn `4,500` copse instances (`18,000` tree crowns in **only 2 GPU draw calls**) grounded via exact triangle-barycentric interpolation (`tx + ty <= 1`) on the `129×129` `horizon.glb` grid (`72%` continuous radial blanket + `28%` direct ridge/dome crowning).

---

## 3. Country Dirt Paths, Trails & Footbridges

### 3.1 Native Terrain Splat Blending (Zero Floating or Buckling)
- **Rule**: Never render land dirt paths as a separate hovering 3D ribbon mesh over sloped terrain triangles—side-slopes cause perspective parallax, buckling, and artificial sticker edges.
- **World-Space SDF Path Mask (`uRoadMaskTex`, `1024×1024`)**:
  - Rasterize the path into a world-space `DataTexture` where:
    - `R` = radial proximity (`1.0` at centerline, `0.50` at nominal edge, `0.0` at `2×` half-width),
    - `G` = signed cross-section coordinate (`0.5` at center, `0.25` at left edge, `0.75` at right edge),
    - `B` = land fade (`1.0 - bridgeMask`).
  - Reserve 3D road geometry strictly for elevated **rustic wooden footbridges** spanning river crossings (`bridgeMask > 0.03`).

### 3.2 Sweeping S-Curves (Eliminating Grid A* Kinks)
- Grid-based A* pathfinders produce sharp 45°/90° zig-zag turns on hillsides.
- Always subsample raw pathfinder points at `~5.2m` spacing and run **16–18 passes of Laplacian curve relaxation** (`0.26 * prev + 0.48 * cur + 0.26 * next`) before fitting a centripetal `CatmullRomCurve3` so the trail flows in long, graceful S-curves.

### 3.3 Kazuo Oga Country Path Anatomy
Inside the terrain fragment shader, perturb `rd.r` with 3 octaves of world-space FBM brushwork (`tuftMacro`, `tuftMed`, `tuftFine`) and composite five poster-color layers:
1. **Trampled Yellow-Olive Grass Verge (`vergeMask`)**: Sun-warmed meadow border (`vec3(0.43, 0.58, 0.22)`) where grass is lightly walked on.
2. **Sunken Raw-Umber Turf Lip (`turfLip`)**: Narrow dark earth shadow (`vec3(0.43, 0.33, 0.23)`) right where overhanging grass tufts meet the sunken trail.
3. **Warm Sun-Baked Ochre & Raw-Sienna Soil (`soilMask`)**: Dry yellow-ochre center (`vec3(0.75, 0.61, 0.43)` to `vec3(0.83, 0.70, 0.51)`) blended with deeper terra-sienna (`vec3(0.59, 0.46, 0.32)`) along the two worn wheel/footpath ruts (`abs(latNorm) ≈ 0.21`).
4. **Intermittent Center Clover & Grass Island (`centerClover`)**: Wild green grass and clover patches growing intermittently down the middle of twin-rut country lanes (`abs(latNorm) < 0.11`).
5. **Sparse Hand-Flicked Pebbles (~6% Coverage)**: High-threshold value noise (`smoothstep(0.76, 0.85, pebbleNoise)`) placing small warm limestone pebbles with a subtle bottom contact shadow.

---

## 4. Terrain, Meadows, Cliffs & Alpine Snow Physics

### 4.1 3-Band Gouache Terrain & Riparian Zones
- **Meadows & Cliffs**: Blend multi-scale FBM meadow greens (`#387d33` to `#70ad40`) with stratified warm-cool limestone cliffs (`#666b70` to `#8a877d`) across `smoothstep(0.40, 0.72, slope)`, modulated by directional gouache brush grain (`surfaceBrush`).
- **Riparian Moss Bench**: Along river corridors (`vRiparian.y`), blend rich moisture-loving moss and sedge greens (`#246330`).

### 4.2 6-Factor Physically Plausible Alpine Snow Model
1. **Orographic Elevation & Summit Rime Cap**: Snow depth and slope retention increase with altitude (`wp.y`). Above `52m–78m`, sub-zero rime ice clings even to steep mountain peaks (`summitRimeCap`), leaving summits completely snow-capped while mid-altitude vertical cliffs (`24m–52m`) shed dry powder to expose dark rock faces for visual contrast.
2. **FBM Domain-Warped Repose**: Warp `N.y` with world-space FBM (`warpMacro`, `warpMicro`) so snow boundaries never follow underlying mesh triangle edges.
3. **Analytical World-Space Snow-Pillow Normals**: Compute snow dune normals analytically in the fragment shader from world-space FBM gradients—never rely on coarse vertex-normal differences that produce jagged `ZZZZ` sawtooth lines.
4. **3D Snow Cross-Section Wall & Lip**: Render a visible glacier-blue cross-section band (`#709edb`) and sunlit white crest along the 3D snow shelf edge, with a dark contact-shadow crease immediately underneath.
5. **Hard Accumulation Cap**: Cap maximum blizzard accumulation at `2.40m` so the valley never becomes unrealistically buried.

---

## 5. Rivers, Shorelines & Optical Water

- **Alluvial Shingle & Capillary Wet Fringe**: Transition from meadow grass to noise-perturbed river gravel (`dryShingle`), darken the capillary wet-stone fringe (`* 0.64`) due to water-film IOR, and tint submerged riverbeds toward optical teal-jade (`#24575c`).
- **Ghibli Water Surface**: Combine shallow turquoise-jade (`#2ad4c4`) and deep cerulean-indigo (`#0e5e8a`) with animated flow-map ripples, crisp stepped white foam crests around banks/shallows, and sun-glint highlights.

---

## 6. Skies, Cumulus Clouds (*Nyudougumo*), & Atmosphere

- **Sky Dome Gradient**: Deep zenith azure (`#155d8a`) transitioning through vibrant mid-sky cyan (`#4ea8cc`) to a warm, humid horizon haze (`#d4eff7`).
- **Cumulus Towers**: Warm cream-white sunlit crowns (`#fffcf0`) with soft periwinkle-violet self-shadowed bases (`#8a7eb4`), scaled monumentally on the horizon.
- **Seasonal Moods**:
  - *Spring*: Crisp azure sky, vibrant emerald meadows, warm golden sun.
  - *Summer Storm*: Slate-blue overcast sky, rain-darkened earth and foliage, wind-whipped waves, and lightning flashes.
  - *Autumn*: Golden-ochre meadows, burnt-sienna/amber tree canopies, russet leaf litter along trails.
  - *Winter*: Soft Ice-blue atmospheric fog, snow-capped peaks and pine boughs, trodden snowy country lanes.

---

## 7. Engineering & UX Quality Gates

1. **Responsive Loading UX**: Never block the main thread silently during startup. Advance a smooth loading progress bar with `requestAnimationFrame` yields across terrain/water/road loading, tree species sculpting, landmark placement, and atmosphere finalization, pausing briefly at `100%` before revealing the scene.
2. **O(1) Bilinear Terrain Height Grid**: Snap landmarks, signposts, bridges, and walkers using a high-resolution (`385×257`, `1.5625m` exact `LOD0` vertex step) bilinear height grid (`sampleTerrainSurfaceHeight`) rather than expensive per-entity raycasts.
3. **Coordinate Space Discipline**: Terrain meshes sit at `+TERRAIN_LIFT` (`+15.0m`). Never double-add `TERRAIN_LIFT` to child groups or snow offsets.
