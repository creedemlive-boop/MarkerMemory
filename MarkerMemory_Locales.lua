-- MarkerMemory localization table (separate file for clarity)
local locale = GetLocale and GetLocale() or "enUS"
local locales = {
    enUS = {
        TITLE = "MarkerMemory",
        READY = "Ready",
        SEQ_EMPTY = "Sequence: empty",
        SEQ = "Sequence: %d Marker",
        SPEED = "Speed",
        START = "Start",
        STAR = "Star",
        CIRCLE = "Circle",
        DIAMOND = "Diamond",
        TRIANGLE = "Triangle",
        MOON = "Moon",
        SQUARE = "Square",
        CROSS = "Cross",
        SKULL = "Skull",
    },
    deDE = {
        TITLE = "MarkerMemory",
        READY = "Bereit",
        SEQ_EMPTY = "Sequenz: leer",
        SEQ = "Sequenz: %d Marker",
        SPEED = "Geschwindigkeit",
        START = "Start",
        STAR = "Stern",
        CIRCLE = "Kreis",
        DIAMOND = "Diamant",
        TRIANGLE = "Dreieck",
        MOON = "Mond",
        SQUARE = "Quadrat",
        CROSS = "Kreuz",
        SKULL = "Totenkopf",
    },
}

local L = locales[locale] or locales.enUS

-- expose to other files
_G.MarkerMemoryLocales = locales
_G.MarkerMemory_L = L
