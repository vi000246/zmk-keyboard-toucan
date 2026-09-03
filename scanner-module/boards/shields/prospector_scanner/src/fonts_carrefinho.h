/*
 * Copyright (c) 2024 The ZMK Contributors
 * SPDX-License-Identifier: MIT
 *
 * Font declarations for Operator layout
 * Original fonts: https://github.com/carrefinho/prospector-zmk-module
 */

#pragma once

#include <lvgl.h>

/* Shared layout fonts */
LV_FONT_DECLARE(FG_Medium_20);              /* Modifiers, USB/BLE labels, slot labels */
LV_FONT_DECLARE(FG_Medium_21);              /* Battery bar number labels */
LV_FONT_DECLARE(FG_Medium_26);              /* FIELD: output indicator */
LV_FONT_DECLARE(FR_Medium_32);              /* WPM label */
LV_FONT_DECLARE(FR_Regular_30);             /* FIELD: battery label */
LV_FONT_DECLARE(FR_Regular_36);             /* FIELD: layer name */
LV_FONT_DECLARE(DINishExpanded_Light_36);   /* Operator/Radii: layer name */
LV_FONT_DECLARE(DINish_Medium_24);          /* Battery labels */
LV_FONT_DECLARE(DINishCondensed_SemiBold_20); /* FIELD: modifier labels */
LV_FONT_DECLARE(DINishCondensed_SemiBold_22); /* Radii modifier labels (text mode) */
LV_FONT_DECLARE(Symbols_Semibold_32);       /* Radii modifier symbols (Mac mode) */

/*
 * 這兩個的 .c 一直都在 CMakeLists 裡編著，只是上游沒宣告過所以用不到。
 * Radii 的儀表板改版（2026-09-03）要用：48px 大字層名 + 28px 修飾鍵符號。
 *
 * ⚠️ glyph 範圍不是每個字型都一樣，挑字型前先看 .c 檔頭的 lv_font_conv opts：
 *    FR_* / PPF_* / Symbols_* / FG_Medium_21 / FG_Medium_24  = 0x20-0x7F（全 ASCII）
 *    DINishCondensed_*                                       = 0x20-0x7E（全 ASCII）
 *    FG_Medium_20 / FG_Medium_26                             = 0x20-0x60（**沒有小寫**）
 *    層名有 '-' 和 '+'（CUR- / CUR+ / SCR- / SCR+），副標有小寫，
 *    所以這兩處都不能用 FG_Medium_20 / FG_Medium_26。
 */
LV_FONT_DECLARE(FR_Regular_48);             /* Radii: 大字層名（固定單行）*/
LV_FONT_DECLARE(Symbols_Semibold_28);       /* Radii: 修飾鍵符號（2x2）*/

/* Mac-style modifier symbols (from carrefinho's symbols.h) */
#define SYMBOL_COMMAND "\xF4\x80\x86\x94"   /* ⌘ */
#define SYMBOL_OPTION "\xF4\x80\x86\x95"    /* ⌥ */
#define SYMBOL_CONTROL "\xF4\x80\x86\x8D"   /* ⌃ */
#define SYMBOL_SHIFT "\xF4\x80\x86\x9D"     /* ⇧ */
#define SYMBOL_SHIFT_FILLED "\xF4\x80\x86\x9E" /* ⇧ filled */
