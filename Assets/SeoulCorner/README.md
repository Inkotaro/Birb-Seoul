# SEOUL CORNER — Low-Poly Korean Neighbourhood Kit  (v1.0)

**530 game-ready low-poly models** of a Korean neighbourhood: a 24-hour convenience store
(fictional brand 누리24 / NURI24) with its interior, products and terrace, red-brick villas, shopfronts,
alleys full of utility poles and tangled wires, street furniture, trees and vehicles.

* Formats: **glTF** (one file per model, shared textures — Godot, Three.js, Unity glTFast, Blender),
  **GLB** (one file per category), **FBX** (Unity, Unreal), **OBJ**, and a **Blender asset library**
  (.blend, every model marked as an asset, catalogues per category).
* **5 shared materials, 3 textures** for the whole kit → very few draw-call/material switches:
  `palette.png` (512², 16×16 colour swatches), `palette_orm.png` (roughness/metallic per swatch),
  `signs.png` (Hangul signage & labels atlas).
* Real-world scale (metres), +Z up in Blender / +Y up in exports, models face **-Y in Blender = +Z
  (glTF forward)**. Origins at the base centre (props) or at the module corner (modular pieces).
* Triangles: 12 – 25,437 per model, 582,236 in total.

| Category | 카테고리 | Models |
|---|---|---:|
| Store Building (modular) | 편의점 건물 (모듈러) | 39 |
| Store Interior Fixtures | 편의점 집기·가전 | 49 |
| Store Products | 편의점 상품 | 75 |
| Store Terrace & Frontage | 편의점 테라스·앞마당 | 33 |
| Neighbourhood Shopfronts | 동네 상가 점포 | 40 |
| Villa Building (modular) | 빨간 벽돌 빌라 (모듈러) | 51 |
| Ground, Roads & Sidewalks | 도로·골목·보도 | 32 |
| Alley Utilities | 골목 인프라 (전봇대·전선·계량기) | 70 |
| Alley Household Props | 골목 생활소품 | 52 |
| Street Furniture | 가로시설물 | 39 |
| Trees & Plants | 나무·식물 | 30 |
| Vehicles | 차량 | 20 |

Full list with sizes and triangle counts: **CONTENTS.md** / `catalog.csv`.

## Folder structure
```
GLTF/<Category>/*.gltf + .bin one file per model, textures referenced from ../../Textures
GLB/SeoulCorner_<Category>.glb all models of a category in one file (textures embedded)
FBX/<Category>/*.fbx          textures referenced from ../../Textures
OBJ/<Category>/*.obj + .mtl   textures referenced from ../../Textures
Blender/SeoulCorner_Library.blend  (+ textures/, blender_assets.cats.txt)
Textures/palette.png palette_orm.png signs.png (+ signs_2k.png, palette_metallic_smoothness.png,
         palette_roughness.png, palette_metallic.png, palette_chart.png)
Previews/                     contact sheets + thumbnails
catalog.json / catalog.csv    machine-readable list
```

## Materials
| Material | Use | Setup |
|---|---|---|
| `SC_Palette` | everything opaque | Base colour = palette.png (**point/nearest filtering**), roughness = G, metallic = B of palette_orm.png |
| `SC_Emissive` | lamps, LED strips, screens | palette.png as base & emission colour, emission strength ≈ 3 (raise at night) |
| `SC_Glass` | windows, fridge doors | palette.png tint, **alpha 0.32 blended**, roughness 0.05 |
| `SC_Signs` | signage, labels | signs.png base colour |
| `SC_Signs_Emissive` | lit signs | signs.png base & emission, strength ≈ 2.2 |

GLB files carry these settings already. For FBX/OBJ, assign the textures as above (most engines
pick up the base colour automatically).

## Engine quick start
**Godot 4** — copy the `GLTF` and `Textures` folders into your project (keep them side by side) or
drag a category `.glb`. Emission and transparency import automatically.
For crisp colours select `palette.png` → Import → Filter: Nearest.
**Unity (URP/HDRP/Built-in)** — import `FBX` + `Textures`. Create 5 materials (Lit): Palette (base map
palette.png, Point filter; metallic map `palette_metallic_smoothness.png`, smoothness source =
metallic alpha), Emissive (same + emission map palette.png), Glass
(Transparent, alpha 0.32), Signs, Signs Emissive; remap on the model importer (Materials tab →
"On Demand Remap"). Or use glTFast with the GLB files to get everything set up.
**Unreal Engine 5** — import `FBX` with "Combine Meshes" off. Set palette.png texture filter to
*Nearest*, compression *UserInterface2D (RGBA)*. `palette_orm.png` is already Unreal-packed (R = AO,
G = roughness, B = metallic). Create one master material per type above and enable *Two Sided* on
the palette material (a few thin parts are single planes).
**Blender** — open `Blender/SeoulCorner_Library.blend`, or add the `Blender` folder as an Asset Library
(Preferences → File Paths → Asset Libraries) and drag models from the Asset Browser.
**Roblox** — use the 3D Importer with FBX/OBJ files (each model is a single mesh under the limits);
import palette.png as the texture (SurfaceAppearance / TextureID).

## Modular grid
Facade/wall modules are 3 m wide (1 m/2 m fillers), walls 0.2 m thick with the exterior face at y = 0.
Shop storey 3.3 m (+0.9 m sign band), villa storey 2.8 m, ground tiles 3 × 3 m, sidewalk curb 0.15 m.
Place modules at multiples of 3 m and rotate by 90° for side walls.

## Recolour / re-sign
* Recolour anything by editing a swatch in `palette.png` (see `palette_chart.png` for names).
* Every sign, label and poster lives in `signs.png`. Paint over it to rename shops or translate the
  signage. `signs_2k.png` is a lighter drop-in replacement (same layout) for mobile/web.

## License
Royalty-free for personal and commercial projects. Do not redistribute or resell the assets
themselves. See LICENSE.txt. All brand names are fictional. Created with AI-assisted procedural
generation (Python scripts that build the meshes); see the store page for the disclosure.

---

# 서울 코너 — 로우폴리 한국 동네 에셋 키트 (v1.0)

**게임에 바로 쓸 수 있는 로우폴리 모델 530종**: 24시간 편의점(가상 브랜드 누리24) 건물·집기·상품·테라스,
빨간 벽돌 빌라, 동네 상가, 전봇대와 얽힌 전선이 있는 골목, 가로시설물, 나무, 차량까지.

* 포맷: GLB · FBX · OBJ · 블렌더 에셋 라이브러리(.blend)
* 키트 전체가 머티리얼 5개, 텍스처 3장(팔레트, 러프니스/메탈릭, 한글 간판 아틀라스)만 씀 → 가볍고 일괄 교체가 쉬움
* 실측 스케일(미터), 블렌더 기준 -Y 방향이 정면, 모듈 그리드 3m
* 간판·라벨은 모두 signs.png 한 장에 있어서 상호명을 마음대로 바꿀 수 있음
* 개인·상업 프로젝트에 로열티 없이 사용 가능(에셋 자체의 재배포·재판매는 금지). 모든 상호는 가상임.
