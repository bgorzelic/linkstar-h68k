#!/bin/sh
# Install the SpookyJuice-branded LuCI theme (uci-defaults fragment).
# Writes the cascade override to /www/luci-static/spooky/ and points LuCI at it.
# The CSS @imports material, so material MUST be installed (it is, in the flagship).

mkdir -p /www/luci-static/spooky
cat > /www/luci-static/spooky/cascade.css <<'SPOOKYCSS'
__CASCADE_CSS__
SPOOKYCSS

# point LuCI's default media base at the spooky theme (falls back gracefully)
uci -q set luci.themes.Spooky='/luci-static/spooky'
uci -q set luci.main.mediaurlbase='/luci-static/spooky'
uci -q commit luci
