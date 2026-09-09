# Hearth & Hollow

A small expedition-game playground for `fu_ui`, using the supplied Kenney RPG
atlas. Run from the repository root:

```powershell
odin run examples/textured_ui
```

Build and serve the web version from the repository root:

```powershell
odin run build_web -- examples/textured_ui
python -m http.server 8000 --directory examples/textured_ui/bin/web
```

Open `http://localhost:8000`. Both platforms share `init`, `step`, and
`shutdown`; desktop `main` runs the frame loop, while the web wrapper calls
`step` once per browser frame. Assets are embedded in the build. UI test files
are excluded from JS builds because `core:testing` requires desktop OS support.

Choose a map waypoint and begin an expedition. Journey progress advances over
time; arriving updates the journal, spends HP/MP, and awards gold if collection
is enabled. Use supplies or rest to restore resources. Camp settings pauses the
journey. State lasts for the current session; supplies are reusable demo items.

## Features demonstrated

| Library feature | In the game |
| --- | --- |
| Nine-sliced window skins | Three pinned game windows and the camp window |
| Panels and nested panels | Character card, map, backpack, and journal quest cards |
| Independent scroll panels | Backpack, quest journal, and camp settings |
| Wheel, thumb dragging, track clicks | Each scroll panel |
| Buttons, labeled buttons, hover/press animation | Expedition, rest, equipment, camp, reset |
| Segmented controls | Backpack category and travel stance |
| Toggles | Reward collection and map routes |
| Slider with quantized steps | Textured journey-speed bar, 0.5x to 2x in 0.25 steps |
| Progress bars | Three-slice orange health and blue mana bars; matching blue journey bar |
| Whole-texture and atlas-region images | Character portrait, items, waypoint marker |
| Labels, alignment, separators, cut-based layout | All panels and the settings form |
| Pinned windows | Backpack, expedition, journal |
| Undecorated, borderless, no-padding window | Transparent top HUD |
| Draggable/resizable window | Camp settings; drag the title or lower-right corner |
| Nested clipping and clipped hit testing | Scroll lists inside window content clips |
| Modal input handling | Camp owns input while the game continues drawing behind it |

## Camera and high DPI

Everything is laid out in a logical 1280 x 800 coordinate system. Each frame the
camera uses the actual drawable size for its centered offset and uniform zoom.
Karl2D rasterizes dynamic-font glyphs at camera zoom, so text uses the available
framebuffer resolution. No separate scaling of widget sizes, fonts, or skin
borders is needed. Different aspect ratios get centered letterboxing.

```odin
camera := k2.Camera {
    target = {640, 400},
    offset = k2.get_screen_size() * 0.5,
    zoom = min(k2.get_screen_size().x / 1280, k2.get_screen_size().y / 800),
}
ui.set_camera(ctx, camera)
ui.update_mouse_screen_pos(ctx, k2.get_mouse_position())
// begin_frame, windows and widgets, end_frame
ui.set_camera(ctx, nil)
```

Set the camera between frames. UI cameras must be axis-aligned (no rotation).
Logical clip rectangles are intersected and used for input before being mapped
to screen-space scissors. `update_mouse_pos` still accepts logical coordinates;
`update_mouse_screen_pos` performs the camera conversion. With no camera, both
input and clips retain their original screen-coordinate behavior.

Widget drawing policies live in `ui/styling.odin`, with shared surface, thumb,
selection, and bar helpers. Atlas regions and theme setup live in `theme.odin`. The scripted integration
input lives in `smoke.odin`, leaving `main.odin` for the game and its layout.

## Texture API

`ui.Skin` borrows a texture and specifies a source rectangle and left/top/right/
bottom borders in source pixels. `border_scale` converts borders into logical UI
units; zero defaults to 1. In this camera-based example it stays at 1. An empty
source selects the whole texture, and zero borders produce a stretched image.

Set `theme.window_skin`, `theme.panel_skin`, and `theme.button_skin` for defaults,
or pass an explicit skin as the fourth argument to `ui.panel`. `ui.draw_skin`
draws without changing layout. `ui.image_region` draws a tinted atlas region;
`ui.image` draws a whole texture. Button theme colors tint their texture.

Nine-slicing uses one quad with UV remapping in D3D11, GL, or WebGL shaders.
Undersized destinations shrink opposing borders proportionally; sampling clamps
to half-texel atlas bounds. Initialization asserts that the slice shader loads.
Per-skin uniforms can split draw calls. Skin drawing restores the default shader,
so keep UI drawing outside other custom shader passes.

Call `ui.destroy(ctx)` and destroy borrowed textures before Karl2D shutdown.

## Bar skins and contrast

`ui.Three_Slice` borrows a texture and three source rectangles (left, middle,
right), allowing caps to live anywhere in an atlas. `ui.Bar_Style` contains
`track`, `fill`, an optional `thumb` skin for sliders, and a logical `height`
(zero defaults to 18). The demo uses the atlas's blue round button as its slider
thumb, preserving its aspect ratio and shading it while dragging. Caps scale with
bar height; only the middle stretches. Shared slice boundaries are snapped in
framebuffer pixels to avoid half-pixel softness. Segmented controls use a
14-unit font by default (override with `font_size`) and keep their textured
highlights at the source's native height inside the full clickable row. Very short fills shrink both caps
proportionally, and empty fills draw nothing. Each piece uses the existing skin
shader for atlas-edge clamping; a bar uses up to three quads per track/fill.

Pass `bar_style=...` to `ui.slider` or `ui.progress_bar`, or set theme defaults
with `theme.slider_bar` and `theme.progress_bar`. `theme.toggle_bar` textures
toggle tracks, and `theme.segmented_selection` takes a `Three_Slice` for the
selected segment and its hover preview. The demo shares the same blue atlas
fill between the speed slider, journey/mana bars, toggles, and segment highlights. Missing track/fill textures
fall back individually to vector drawing. Without a style, the original vector
widgets remain available. The demo applies per-widget health/mana styles and a
blue theme style to the speed slider.

Segmented pickers share `theme.panel_skin`, falling back to their original color
background when no panel skin is set. Scrollbars have independent
`scrollbar_track`, `scrollbar_thumb`, `scrollbar_hover`, and `scrollbar_active`
colors (used as tints when textured). Optional `theme.toggle_thumb_skin` and
`theme.scrollbar_thumb_skin` texture the other handle controls. The demo shares
the slider's round blue artwork with toggles, and nine-slices the blue square
button for scrollbars, retaining dark tints and contrasting grip marks against
the paper. Without these skins the original vector handles are still used.

## Validation

```powershell
odin test examples/textured_ui/ui
odin run examples/textured_ui -define:UI_SMOKE_TEST=true -define:KARL2D_AUDIO_BACKEND=nil
odin run examples/textured_ui -define:UI_SMOKE_TEST=true -define:KARL2D_AUDIO_BACKEND=nil -define:KARL2D_RENDER_BACKEND=gl
```

The 23-frame integration smoke exercises initialization, independent scrolling,
modal blocking, dragging, resizing, map selection, expedition start, toggle
changes, and slider interaction. Camera tests cover fractional scaling, 4K,
portrait letterboxing, empty clips, clipped input, and the no-camera path.
Bar tests cover normal, scaled, empty, tiny, and asymmetric end caps.
D3D11 and GL smoke runs pass, as do D3D11 runs at 2560 x 1600 and 900 x 1200
(`-define:UI_WIDTH=2560 -define:UI_HEIGHT=1600` sets the initial window size).

GL and WebGL share shader sources with backend-specific version headers.
WebGL has not been browser-tested. Hidden-window
capture returns a blank image here, so visual high-DPI QA still needs a desktop
run. The portrait is copied from the repository's space_cat example.
