package textured_ui

import k2 "../.."
import ui "ui"

ATLAS_WINDOW :: k2.Rect{0, 376, 100, 100}
ATLAS_PANEL :: k2.Rect{200, 294, 93, 94}
ATLAS_CARD :: k2.Rect{190, 100, 100, 100}
ATLAS_BUTTON :: k2.Rect{0, 188, 190, 49}
ATLAS_ROUND_THUMB :: k2.Rect{335, 38, 35, 38}
ATLAS_SCROLL_THUMB :: k2.Rect{290, 0, 45, 49}

ATLAS_TRACK_LEFT :: k2.Rect{372, 330, 9, 18}
ATLAS_TRACK_MIDDLE :: k2.Rect{338, 386, 18, 18}
ATLAS_TRACK_RIGHT :: k2.Rect{190, 294, 9, 18}

ATLAS_ORANGE_LEFT :: k2.Rect{370, 90, 9, 18}
ATLAS_ORANGE_MIDDLE :: k2.Rect{356, 368, 18, 18}
ATLAS_ORANGE_RIGHT :: k2.Rect{190, 348, 9, 18}

ATLAS_BLUE_LEFT :: k2.Rect{372, 294, 9, 18}
ATLAS_BLUE_MIDDLE :: k2.Rect{356, 431, 18, 18}
ATLAS_BLUE_RIGHT :: k2.Rect{372, 312, 9, 18}

ATLAS_BLADE :: k2.Rect{335, 152, 34, 37}
ATLAS_KEY :: k2.Rect{338, 294, 34, 37}
ATLAS_LEATHER_GLOVES :: k2.Rect{0, 482, 30, 30}
ATLAS_SILVER_GAUNTLET :: k2.Rect{60, 482, 30, 30}
ATLAS_GREEN_POTION :: k2.Rect{370, 108, 9, 18}
ATLAS_SEAL :: k2.Rect{335, 76, 35, 38}
ATLAS_KNIFE :: k2.Rect{338, 331, 34, 37}
ATLAS_COIN :: k2.Rect{369, 152, 17, 17}
ATLAS_TRAVEL_GLOVES :: k2.Rect{30, 482, 30, 30}
ATLAS_YELLOW_POTION :: k2.Rect{370, 126, 9, 18}

ATLAS_WAYPOINT :: k2.Rect{171, 486, 22, 21}

skin :: proc(source: k2.Rect) -> ui.Skin {
	return {texture = atlas, source = source, borders = {8, 8, 8, 8}, border_scale = 1}
}

init_theme :: proc() {
	ctx.theme.window_skin = skin(ATLAS_WINDOW)
	ctx.theme.panel_skin = skin(ATLAS_PANEL)
	ctx.theme.button_skin = skin(ATLAS_BUTTON)
	track := ui.Three_Slice {
		texture = atlas,
		source  = {ATLAS_TRACK_LEFT, ATLAS_TRACK_MIDDLE, ATLAS_TRACK_RIGHT},
	}
	health_bar = {
		track = track,
		fill = {
			texture = atlas,
			source = {ATLAS_ORANGE_LEFT, ATLAS_ORANGE_MIDDLE, ATLAS_ORANGE_RIGHT},
		},
		height = 18,
	}
	mana_bar = {
		track = track,
		fill = {
			texture = atlas,
			source = {ATLAS_BLUE_LEFT, ATLAS_BLUE_MIDDLE, ATLAS_BLUE_RIGHT},
		},
		height = 18,
	}
	// Share the blue fill across controls.
	ctx.theme.progress_bar = mana_bar
	ctx.theme.toggle_bar = mana_bar
	ctx.theme.segmented_selection = mana_bar.fill
	ctx.theme.slider_bar = mana_bar
	ctx.theme.slider_bar.thumb = {
		texture = atlas,
		source  = ATLAS_ROUND_THUMB,
	}
	ctx.theme.toggle_thumb_skin = ctx.theme.slider_bar.thumb
	// The bottom cap includes the curve and drop shadow.
	ctx.theme.scrollbar_thumb_skin = {
		texture = atlas,
		source  = ATLAS_SCROLL_THUMB,
		borders = {4, 4, 4, 10},
	}
	ctx.theme.scrollbar_track = {167, 143, 98, 255}
	ctx.theme.scrollbar_thumb = {165, 180, 205, 255}
	ctx.theme.scrollbar_hover = {205, 215, 240, 255}
	ctx.theme.scrollbar_active = {145, 165, 200, 255}
	ctx.theme.text = INK
	ctx.theme.title_text = CREAM
	ctx.theme.title_bg = {101, 76, 49, 255}
	ctx.theme.widget_bg = {173, 151, 105, 255}
	ctx.theme.widget_hover = {207, 195, 167, 255}
	ctx.theme.widget_active = GOLD
	ctx.theme.accent = {45, 175, 218, 255}
	ctx.theme.separator = {88, 71, 45, 110}
}
