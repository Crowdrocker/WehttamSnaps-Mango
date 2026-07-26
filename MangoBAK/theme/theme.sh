#!/usr/bin/env bash
set -euo pipefail

## Copyright (C) 2020-2026 Aditya Shakya <adi1090x@gmail.com>
##
## Script To Apply Themes -----------------------------------

## Directories ----------------------------------------------
DIR="$HOME/.config/mango"
PATH_ALAC="$DIR/alacritty"
PATH_FOOT="$DIR/foot"
PATH_KITY="$DIR/kitty"
PATH_MAKO="$DIR/mako"
PATH_ROFI="$DIR/rofi"
PATH_WAYB="$DIR/waybar"
PATH_WLOG="$DIR/wlogout"

## Helpers --------------------------------------------------
run_bg() {
	setsid "$@" >/dev/null 2>&1 &
}

safe_restart() {
	local proc="$1"; shift

	if pgrep -x "$proc" >/dev/null; then
		pkill -TERM -x "$proc"
		while pgrep -x "$proc" >/dev/null; do
			sleep 0.1
		done
	fi

	"$@" &
}

reload_or_start() {
	local proc="$1"
	local reload_cmd="$2"
	local start_cmd="$3"

	if pgrep -x "$proc" >/dev/null; then
		eval "$reload_cmd"
	else
		eval "$start_cmd &"
	fi
}

write_if_changed() {
	local file="$1"
	local tmp
	tmp=$(mktemp)

	cat > "$tmp"

	if ! cmp -s "$tmp" "$file" 2>/dev/null; then
		mv "$tmp" "$file"
	else
		rm "$tmp"
	fi
}

notify() {
	notify-send \
		-h string:x-canonical-private-synchronous:sys-notify-theme \
		-u normal \
		-i "${PATH_MAKO}/icons/palette.png" \
		"$1"
}

## Theme Sources --------------------------------------------
CURRENT_THEME="$DIR/theme/current.bash"
DEFAULT_THEME="$DIR/theme/default.bash"
LIGHT_THEME="$DIR/theme/light.bash"
PYWAL_THEME="$HOME/.cache/wal/colors.sh"

apply_palette_math() {
	altbackground="$(pastel color "$background" | pastel lighten 0.10 | pastel format hex)"
	altforeground="$(pastel color "$foreground" | pastel darken 0.30 | pastel format hex)"
	mapfile -t modbackground < <(pastel gradient -n 3 "$background" "$altbackground" | pastel format hex)
}

# Default Theme
source_default() {
	cp "$DEFAULT_THEME" "$CURRENT_THEME"
	source "$CURRENT_THEME"
	apply_palette_math
	accent="$accentc"
	notify "Applying Default Theme…"
}

# Light Theme
source_light() {
	cp "$LIGHT_THEME" "$CURRENT_THEME"
	source "$CURRENT_THEME"
	altbackground="$(pastel color "$background" | pastel darken 0.15 | pastel format hex)"
	altforeground="$(pastel color "$foreground" | pastel lighten 0.30 | pastel format hex)"
	mapfile -t modbackground < <(pastel gradient -n 3 "$background" "$altbackground" | pastel format hex)
	accent="$color3"
	notify "Applying Light Theme…"
}

# Random Theme
source_pywal() {
	# Set you wallpaper directory here.
	WALLDIR="$(xdg-user-dir PICTURES)/wallpapers"

	# Create directory if missing
	if [[ ! -d "$WALLDIR" ]]; then
		mkdir -p "$WALLDIR"

		notify-send \
			-h string:x-canonical-private-synchronous:sys-notify-noimg \
			-u low \
			-i "${PATH_MAKO}/icons/picture.png" \
			"Put some wallpapers in: $WALLDIR"

		exit 1
	fi

	# Check if wallpapers exist
	shopt -s nullglob
	mapfile -t WALLPAPERS < <(find "$WALLDIR" -type f \( \
		-iname "*.jpg" -o \
		-iname "*.jpeg" -o \
		-iname "*.png" -o \
		-iname "*.webp" -o \
		-iname "*.bmp" \))

	if (( ${#WALLPAPERS[@]} == 0 )); then
		notify-send \
			-h string:x-canonical-private-synchronous:sys-notify-noimg \
			-u low \
			-i "${PATH_MAKO}/icons/picture.png" \
			"There are no wallpapers in: $WALLDIR"

		exit 1
	fi

	# Check pywal
	if ! command -v wal >/dev/null 2>&1; then
		notify-send \
			-h string:x-canonical-private-synchronous:sys-notify-runpywal \
			-u normal \
			-i "${PATH_MAKO}/icons/palette.png" \
			"'pywal' is not installed."

		exit 1
	fi

	# Generate Colors
	notify-send \
		-t 50000 \
		-h string:x-canonical-private-synchronous:sys-notify-runpywal \
		-i "${PATH_MAKO}/icons/timer.png" \
		"Generating colorscheme. Please wait..."

	if ! wal -q -n -s -t -e -i "$WALLDIR"; then
		notify-send \
			-h string:x-canonical-private-synchronous:sys-notify-runpywal \
			-u normal \
			-i "${PATH_MAKO}/icons/palette.png" \
			"Failed to generate colorscheme."
		exit 1
	else
		makoctl dismiss	
	fi

	# Load Generated Theme
	cp "$PYWAL_THEME" "$CURRENT_THEME"
	sed -i '/# FZF colors/Q' "$CURRENT_THEME"
	source "$CURRENT_THEME"
	apply_palette_math
	accent="$color5"
}

## Apply Components -----------------------------------------

apply_wallpaper() {
	sed -i "s#WALLPAPER=.*#WALLPAPER='$wallpaper'#g" \
		"$DIR/scripts/wallpaper"

	run_bg bash "$DIR/scripts/wallpaper"
}

apply_alacritty() {
	write_if_changed "$PATH_ALAC/colors.toml" <<- EOF
		## Colors configuration
		[colors.primary]
		background = "${background}"
		foreground = "${foreground}"
		
		[colors.normal]
		black   = "${color0}"
		red     = "${color1}"
		green   = "${color2}"
		yellow  = "${color3}"
		blue    = "${color4}"
		magenta = "${color5}"
		cyan    = "${color6}"
		white   = "${color7}"
		
		[colors.bright]
		black   = "${color8}"
		red     = "${color9}"
		green   = "${color10}"
		yellow  = "${color11}"
		blue    = "${color12}"
		magenta = "${color13}"
		cyan    = "${color14}"
		white   = "${color15}"
	EOF
}

apply_foot() {
	write_if_changed "$PATH_FOOT/colors.ini" <<- EOF
		## Colors configuration
		[colors-dark]
		alpha=1.0
		foreground=${foreground:1}
		background=${background:1}

		## Normal/regular colors (color palette 0-7)
		regular0=${color0:1}  # black
		regular1=${color1:1}  # red
		regular2=${color2:1}  # green
		regular3=${color3:1}  # yellow
		regular4=${color4:1}  # blue
		regular5=${color5:1}  # magenta
		regular6=${color6:1}  # cyan
		regular7=${color7:1}  # white

		## Bright colors (color palette 8-15)
		bright0=${color8:1}   # bright black
		bright1=${color9:1}   # bright red
		bright2=${color10:1}   # bright green
		bright3=${color11:1}   # bright yellow
		bright4=${color12:1}   # bright blue
		bright5=${color13:1}   # bright magenta
		bright6=${color14:1}   # bright cyan
		bright7=${color15:1}   # bright white
	EOF
}

apply_kitty() {
	write_if_changed "$PATH_KITY/colors.conf" <<- EOF
		## Colors configuration
		background ${background}
		foreground ${foreground}
		selection_background ${foreground}
		selection_foreground ${background}
		cursor ${foreground}
		
		color0 ${color0}
		color8 ${color8}
		color1 ${color1}
		color9 ${color9}
		color2 ${color2}
		color10 ${color10}
		color3 ${color3}
		color11 ${color11}
		color4 ${color4}
		color12 ${color12}
		color5 ${color5}
		color13 ${color13}
		color6 ${color6}
		color14 ${color14}
		color7 ${color7}
		color15 ${color15}
	EOF

	pkill -USR1 kitty 2>/dev/null || true
}

apply_mako() {
	sed -i '/# Mako_Colors/Q' "$PATH_MAKO/config"

	cat >> "$PATH_MAKO/config" <<- EOF
		# Mako_Colors
		background-color=${background}
		text-color=${foreground}
		border-color=${modbackground[2]}
		progress-color=over ${accent}

		[urgency=low]
		border-color=${modbackground[2]}
		default-timeout=2000

		[urgency=normal]
		border-color=${modbackground[2]}
		default-timeout=5000

		[urgency=high]
		border-color=${color1}
		text-color=${color1}
		default-timeout=0
	EOF

	reload_or_start \
		mako \
		"makoctl reload" \
		"bash $DIR/scripts/notifications"
}

apply_rofi() {
	write_if_changed "$PATH_ROFI/shared/colors.rasi" <<- EOF
		* {
		    background:      ${background};
		    background-alt1: ${modbackground[1]};
		    background-alt2: ${modbackground[2]};
		    foreground:      ${foreground};
		    selected:        ${accent};
		    active:          ${color2};
		    urgent:          ${color1};
		}
	EOF
}

apply_waybar() {
	write_if_changed "$PATH_WAYB/colors.css" <<- EOF
		/** ********** Colors ********** **/
		@define-color background      ${background};
		@define-color background-alt1 ${modbackground[1]};
		@define-color background-alt2 ${modbackground[2]};
		@define-color foreground      ${foreground};
		@define-color selected        ${accent};
		@define-color black           ${color0};
		@define-color red             ${color1};
		@define-color green           ${color2};
		@define-color yellow          ${color3};
		@define-color blue            ${color4};
		@define-color magenta         ${color5};
		@define-color cyan            ${color6};
		@define-color white           ${color7};
	EOF

	reload_or_start \
		waybar \
		"pkill -USR2 waybar" \
		"bash $DIR/scripts/statusbar"
}

apply_wlogout() {
	write_if_changed "$PATH_WLOG/colors.css" <<- EOF
		/** ********** Colors ********** **/
		@define-color background      ${background};
		@define-color background-alt1 ${modbackground[1]};
		@define-color background-alt2 ${modbackground[2]};
		@define-color foreground      ${foreground};
		@define-color selected        ${accent};
		@define-color black           ${color0};
		@define-color red             ${color1};
		@define-color green           ${color2};
		@define-color yellow          ${color3};
		@define-color blue            ${color4};
		@define-color magenta         ${color5};
		@define-color cyan            ${color6};
		@define-color white           ${color7};
	EOF
}

apply_gtk() {
	sed -i "$DIR/scripts/gtkthemes" \
		-e "s|THEME=.*|THEME='$gtk_theme'|g" \
		-e "s|ICONS=.*|ICONS='$gtk_icons'|g" \
		-e "s|FONT=.*|FONT='$gtk_font'|g" \
		-e "s|CURSOR=.*|CURSOR='$cursor_theme'|g"

	# Cursor Theme
	sed -i "s|cursor_theme=.*|cursor_theme=$cursor_theme|g"	"$DIR/config.d/01-appearance.conf"

	run_bg bash "$DIR/scripts/gtkthemes"
}

apply_geany() {
	sed -i \
		"s/color_scheme=.*/color_scheme=$geany_colors/g" \
		"$HOME/.config/geany/geany.conf"
}

apply_hyprlock() {
	# convert colors to rgb format
	col_hl="`pastel color ${accent} | pastel format rgb | sed 's/rgb(\(.*\))/rgba(\1, 1.0)/'`"
	col_tx="`pastel color ${foreground} | pastel format rgb | sed 's/rgb(\(.*\))/rgba(\1, 1.0)/'`"
	col_oc="`pastel color ${modbackground[1]} | pastel format rgb | sed 's/rgb(\(.*\))/rgba(\1, 0.5)/'`"
	col_ic="`pastel color ${modbackground[2]} | pastel format rgb | sed 's/rgb(\(.*\))/rgba(\1, 0.5)/'`"
	col_fc="`pastel color ${color1} | pastel format rgb | sed 's/rgb(\(.*\))/rgba(\1, 1.0)/'`"

	sed -i "$DIR/hyprlock.conf" \
		-e "s|\$wallpaper =.*|\$wallpaper = $wallpaper|g" \
		-e "s|\$accent_color =.*|\$accent_color = $col_hl |g" \
		-e "s|\$accent_color_hex =.*|\$accent_color_hex = #${accent}FF |g" \
		-e "s|\$text_color =.*|\$text_color = $col_tx |g" \
		-e "s|\$text_color_hex =.*|\$text_color_hex = #${foreground}FF |g" \
		-e "s|\$inner_color =.*|\$inner_color = $col_ic |g" \
		-e "s|\$outer_color =.*|\$outer_color = $col_oc |g" \
		-e "s|\$fail_color =.*|\$fail_color = $col_fc |g"
}


apply_mango() {
	mango_cfg="$DIR/config.d/01-appearance.conf"

	# Colors
	sed -i "$mango_cfg" \
		-e "s|rootcolor=.*|rootcolor=0x${background:1}FF|g" \
		-e "s|bordercolor=.*|bordercolor=0x${modbackground[1]:1}FF|g" \
		-e "s|focuscolor=.*|focuscolor=0x${accent:1}FF|g" \
		-e "s|maximizescreencolor=.*|maximizescreencolor=0x${color2:1}FF|g" \
		-e "s|urgentcolor=.*|urgentcolor=0x${color1:1}FF|g" \
		-e "s|scratchpadcolor=.*|scratchpadcolor=0x${color3:1}FF|g" \
		-e "s|globalcolor=.*|globalcolor=0x${color4:1}FF|g" \
		-e "s|overlaycolor=.*|overlaycolor=0x${color6:1}FF|g"
		
	# Reload Config
	mmsg -d reload_config
}

## Theme Selection ------------------------------------------

case "${1:-}" in
	--default)
		source_default
		apply_gtk
		apply_geany
		;;
	--light)
		source_light
		apply_gtk
		apply_geany
		;;
	--pywal)
		source_pywal
		;;
	*)
		echo "Options: --default  --light  --pywal"
		exit 1
		;;
esac

## Parallel Apply Phase -------------------------------------
apply_wallpaper &
apply_alacritty &
apply_foot &
apply_kitty &
apply_rofi &
apply_wlogout &
apply_hyprlock &
apply_mango &

wait

# UI reload last (prevents flicker / race)
apply_mako
apply_waybar

exit 0
