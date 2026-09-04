/*
 * Copyright (c) 2024 The ZMK Contributors
 * SPDX-License-Identifier: MIT
 *
 * Radii Layout — Toucan 儀表板改版
 *
 * 原始設計來自 carrefinho 的 prospector-zmk-module（輪盤 + 大字層名）。
 * 2026-09-03 在這個 fork 裡重寫成「儀表板」，動機有四個，全部是原版
 * 在這台鍵盤上的實際問題：
 *
 *   1. 輪盤上限 10 格（Kconfig PROSPECTOR_MAX_LAYERS range 4-10，而且
 *      draw_wheel() 自己還有一道 layer_count <= 16 的 guard）。這台鍵盤
 *      當時有 17 層 ⇒ 一半的層輪盤不亮、轉到哪都沒意義。改成左緣一格一層
 *      的 ladder（2026-09-04 起是 13 格，見 LAYER_COUNT）。
 *   2. 三塊高彩度面板（#ACB9D3 淺藍灰 + #1448AA 寶藍 + #E2FF61 螢光黃綠）
 *      擠在 280px 裡互相搶眼，沒有主從。改成全暗底 + hairline，accent
 *      只用在「現在是什麼狀態」上。
 *   3. 小抄面板寫死 240 寬，但螢幕是 280 ⇒ 右邊 40px 漏出底下的面板。
 *      這是純 bug，順手修掉。
 *   4. 電量只有兩個 arc，看得出「大概還有」，看不出幾 %。改成數字 + bar。
 *
 * 版面（280 x 240，ST7789V，硬體 y-offset 已由 driver 處理）：
 *
 *   x=14   13 格 ladder（亮的那格 = 目前層 index）
 *   x=34   index 兩位數 / 大字層名 / hairline / 副標一 / 副標二
 *   x=206  垂直 hairline
 *   x=220  修飾鍵 2x2 / 左右電量（數字 + bar）/ BLE profile 四點
 *
 * ⚠️ 大字層名固定 FR_Regular_48、單行、不 wrap 不縮字。這是刻意的：
 *    keymap 那邊保證每個 display-name 都 ≤ 4 字元（見 config/toucan.keymap
 *    檔頭的層名表），所以溢出在結構上不可能發生。**如果哪天層名變長了，
 *    這裡不會自動換行，會直接被切掉**——要嘛改回 ≤4 字，要嘛改這裡。
 */

#include "radii_layout.h"
#include "fonts_carrefinho.h"
#include "fonts.h"
#include <zephyr/logging/log.h>
#include <zephyr/sys/util.h>
#include <zephyr/toolchain.h>   /* BUILD_ASSERT */
#include <string.h>
#include <stdio.h>

LOG_MODULE_REGISTER(radii_layout, CONFIG_ZMK_LOG_LEVEL);

/* ========== 版面常數 ========== */
#define SCR_W 280
#define SCR_H 240

#define LADDER_X      14
#define LADDER_Y      26
#define LADDER_W       6
#define LADDER_PITCH  11
#define TICK_H         4
#define TICK_ON_W     12
#define TICK_ON_H      6

#define TEXT_X        34
#define TEXT_W       (206 - TEXT_X)   /* 172px，副標的可用寬度 */

#define COL_X        206              /* 垂直分隔線 */
#define RIGHT_X      220

#define BAR_W         44
#define BAR_H          3

/* ========== 層名表 ==========
 *
 * 用廣播帶來的 active_layer 當 index 查。副標不經過 BLE 廣播，所以完全不受
 * layer_name[4] 那 4 bytes 的限制——大字是「CUR-」，副標可以寫「CURSOR SLOW
 * / 0.62x / lockable」。
 *
 * ⚠️ 這張表鏡射 config/toucan.keymap 的**層順序**。
 *    - 只改層名（display-name）⇒ 這裡不用動（大字直接用廣播的名字）。
 *    - 加層 / 刪層 / 重排層 ⇒ 一定要回來更新這張表，否則副標會對到錯的層。
 *    name 欄位只是廣播層名為空時的 fallback。
 */
struct toucan_layer {
    const char *name;
    const char *sub1;
    const char *sub2;
};

static const struct toucan_layer LAYERS[] = {
    { "BASE", "TYPING",      "13 layers"        },
    { "NAV",  "ARROWS",      "windows / claude" },
    { "NUM",  "NUMPAD",      "keypad + mods"    },
    { "SYM",  "SYMBOLS",     "cheatsheet"       },
    { "CMD",  "SHORTCUTS",   "window / clipbrd" },
    { "FUN",  "FUNCTION",    "F1-F12 / volume"  },
    { "PAD",  "TRACKPAD",    "click / speed"    },
    { "SCRL", "WHEEL MODE",  "pad + keyboard"   },
    { "CUR-", "CURSOR SLOW", "1.25x"            },
    { "CUR+", "CURSOR FAST", "3.75x"            },
    { "SCR-", "SCROLL SLOW", "50%"              },
    { "SCR+", "SCROLL FAST", "200%"             },
    { "BT",   "PAIRING",     "profile / output" },
};

/*
 * ladder 的格數。寫成字面常數而不是 ARRAY_SIZE(LAYERS)，因為它同時要當
 * ticks[] 的陣列維度——Zephyr 的 ARRAY_SIZE 展開帶 __builtin_types_compatible_p，
 * 拿來當維度在某些版本會出事。下面的 BUILD_ASSERT 保證兩者不會脫鉤：
 * 在 keymap 加一層卻忘了更新 LAYERS[]，會直接編譯失敗而不是默默對錯副標。
 */
#define LAYER_COUNT 13
BUILD_ASSERT(ARRAY_SIZE(LAYERS) == LAYER_COUNT,
             "LAYERS[] must have one entry per keymap layer (see config/toucan.keymap)");

/* ========== 調色盤 ==========
 *
 * 全部是暗底 + 單一 accent 的變體。非觸控模式開機固定用第 0 個；觸控版本
 * 可以用 radii_layout_cycle_palette() 循環（prospector_layouts.c 在用）。
 */
typedef struct {
    uint32_t bg;       /* 螢幕底色 */
    uint32_t rule;     /* hairline、未亮的 ladder 格、bar 底 */
    uint32_t name;     /* 大字層名 */
    uint32_t index;    /* 兩位數 index */
    uint32_t accent;   /* 目前層、副標一、亮起的修飾鍵、電量 bar、BLE */
    uint32_t mod_off;  /* 沒按下的修飾鍵 */
    uint32_t sub2;     /* 副標二 */
    uint32_t value;    /* 電量數字 */
    const char *pname;
} radii_color_palette_t;

static const radii_color_palette_t color_palettes[] = {
    { 0x0B0E0C, 0x232A26, 0xF2F7F4, 0x4E5A53, 0x43CBA6, 0x2A322D, 0x57635B, 0xE4EAE6, "Mint"  },
    { 0x0E0C0A, 0x2A2620, 0xF7F4F0, 0x5A5348, 0xE0A24E, 0x322D26, 0x635B4E, 0xEAE6E0, "Amber" },
    { 0x0A0C0E, 0x202730, 0xF0F4F7, 0x4B5560, 0x5AA9E6, 0x28303A, 0x53606B, 0xE0E7EA, "Ice"   },
    { 0x0E0A0C, 0x2E2228, 0xF7F0F3, 0x5E4A52, 0xE06E93, 0x352730, 0x6B535D, 0xEAE0E4, "Rose"  },
};

#define PALETTE_COUNT ((int)ARRAY_SIZE(color_palettes))
static uint8_t current_palette = 0;

#define PAL (&color_palettes[current_palette])

/* ========== 物件 ========== */
static lv_obj_t *parent_screen = NULL;
static bool layout_created = false;

static lv_obj_t *bg_obj = NULL;
static lv_obj_t *ticks[LAYER_COUNT] = { NULL };
static lv_obj_t *index_label = NULL;
static lv_obj_t *name_label = NULL;
static lv_obj_t *hrule = NULL;
static lv_obj_t *sub1_label = NULL;
static lv_obj_t *sub2_label = NULL;
static lv_obj_t *vrule = NULL;
static lv_obj_t *mod_labels[4] = { NULL };
static lv_obj_t *bat_value[2] = { NULL };
static lv_obj_t *bat_tag[2] = { NULL };
static lv_obj_t *bat_bar_bg[2] = { NULL };
static lv_obj_t *bat_bar_fill[2] = { NULL };
static lv_obj_t *ble_dots[4] = { NULL };

static uint8_t current_layer = 0xFF;   /* 0xFF = 尚未設定，強制第一次更新 */

/* ========== 小工具 ========== */

static lv_obj_t *rl_rect(lv_obj_t *parent, int x, int y, int w, int h, uint32_t color, int radius) {
    lv_obj_t *o = lv_obj_create(parent);
    lv_obj_set_size(o, w, h);
    lv_obj_set_pos(o, x, y);
    lv_obj_set_style_bg_color(o, lv_color_hex(color), LV_PART_MAIN);
    lv_obj_set_style_bg_opa(o, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_border_width(o, 0, LV_PART_MAIN);
    lv_obj_set_style_radius(o, radius, LV_PART_MAIN);
    lv_obj_set_style_pad_all(o, 0, LV_PART_MAIN);
    lv_obj_clear_flag(o, LV_OBJ_FLAG_SCROLLABLE);
    return o;
}

static lv_obj_t *rl_label(lv_obj_t *parent, int x, int y, const lv_font_t *font,
                       uint32_t color, const char *text) {
    lv_obj_t *l = lv_label_create(parent);
    lv_obj_set_style_text_font(l, font, LV_PART_MAIN);
    lv_obj_set_style_text_color(l, lv_color_hex(color), LV_PART_MAIN);
    lv_obj_set_pos(l, x, y);
    lv_label_set_text(l, text);
    return l;
}

/* ========== SYM 按鍵小抄 overlay（本 fork 加的，上游沒有）==========
 *
 * 廣播的層名等於 CHEAT_LAYER_NAME 時，蓋一層全螢幕小抄；離開該層就藏起來。
 * 手寫表，鏡射 config/toucan.keymap 的 SYM 層。改 SYM 層 bindings 時
 * 「三個地方」要一起改：
 *   1. config/toucan.keymap（真正的鍵位）
 *   2. boards/shields/nice_view_gem/widgets/cheatsheet.c（鍵盤螢幕的小抄）
 *   3. 這裡（dongle 螢幕的小抄）
 *
 * 廣播的層名欄位只有 4 字元，所以比對目標必須 ≤ 4 字。SYM 刻意不改名，
 * 就是因為這裡和 cheatsheet.c 都是用「層名字串」查表，不是用 index。
 */
#define CHEAT_LAYER_NAME "SYM"
#define CHEAT_ROWS 3
#define CHEAT_COLS 5                  /* 每隻手 5 欄 */
#define CHEAT_HANDS 2

/*
 * ── 2026-09-04：為什麼從「一排一個 label」改成「一欄一個 label」──────────
 *
 * 原本是三個 label、每個放一整排字串（"? ! [ ] +   @ # $ \" `"），靠
 * lv_font_unscii_16 是等寬字型讓欄位自然對齊。實機上右手只看得到第一欄
 * （@ / ~ / ^，也就是 Y H N 那一直排），後面全被切掉。
 *
 * 原因是字寬算錯了：**lv_font_unscii_16 的 adv_w = 256（單位 1/16 px）
 * ⇒ 每個字 16px 寬**，不是 UNSCII 點陣原始的 8px。加上 letter_space 2：
 *
 *     21 個字元 x 18px = 376px   而螢幕只有 280px
 *
 * 從 x=20 起算，切在第 (280-20)/18 = 14.4 個字元 ⇒ index 12 的 '@' 是最後
 * 一個完整字，index 14 的 '#' 開始被切。跟實機看到的完全吻合。
 *
 * 改法是「不要再依賴字寬」：每一欄自己一個 label、x 座標直接算出來，欄內
 * 三個字用 '\n' 疊成三排。字型換成什麼、letter_space 設多少，欄位都不會跑，
 * 而且每個 label 一行只有 1 個字元，結構上不可能 wrap。
 *
 * 版面（螢幕 280 寬）：
 *     欄寬 24px x 10 欄 = 240，兩手之間 20px 溝，左右各留 10px
 *     左手 x = 10  34  58  82 106     (溝)     右手 x = 150 174 198 222 246
 * 右端 246+24 = 270 < 280 ✓
 *
 * 鍵盤端的 nice_view 小抄（cheatsheet.c）本來就是逐格畫的，所以沒中這個雷，
 * 不用跟著改。
 */

/* 版面常數 */
#define CHEAT_CELL_W   24
#define CHEAT_GUTTER   20
#define CHEAT_X0       10
#define CHEAT_X1       (CHEAT_X0 + CHEAT_COLS * CHEAT_CELL_W + CHEAT_GUTTER)  /* 150 */
#define CHEAT_Y0       92
#define CHEAT_LINE_SP  32             /* 排距（unscii_16 的 line-height 是 17px）*/
#define CHEAT_FONT_LH  17
#define CHEAT_DIV_X    (CHEAT_X0 + CHEAT_COLS * CHEAT_CELL_W + CHEAT_GUTTER / 2 - 1)

static lv_obj_t *cheat_panel = NULL;
static lv_obj_t *cheat_title = NULL;
static lv_obj_t *cheat_sub = NULL;
static lv_obj_t *cheat_rule = NULL;
static lv_obj_t *cheat_divider = NULL;
static lv_obj_t *cheat_col_labels[CHEAT_COLS * CHEAT_HANDS] = { NULL };

/*
 * 來源表維持「一排一排」寫，跟 keymap 的鍵位圖同構，好對照；欄字串在
 * create_cheat_panel() 裡才組出來。空字串 = 那顆不是符號（純 modifier）。
 * 對照 keymap 鍵位 index：row0=1-5|6-10、row1=13-17|18-22、row2=25-29|30-34。
 */
static const char *cheat_cells[CHEAT_ROWS][CHEAT_COLS * CHEAT_HANDS] = {
    /*  1    2    3    4    5   |   6    7    8    9   10  */
    { "?", "!", "[", "]", "+",   "@", "#", "$", "\"", "`" },
    /* 13   14   15   16   17   |  18   19   20   21   22  */
    /* 20/21 是 LGUI/LCTRL，純 modifier，留白 */
    { "<", ">", "(", ")", "-",   "~", "'",  "",  "",  ":" },
    /* 25   26   27   28   29   |  30   31   32   33   34  */
    { "|", "&", "{", "}", "=",   "^", "*", ",", "\\", "/" },
};

/* 每欄最多 3 個字元 + 2 個 '\n' + 結尾 '\0'，這裡給到 8 純粹是留餘裕。 */
static char cheat_col_text[CHEAT_COLS * CHEAT_HANDS][8];

static void create_cheat_panel(lv_obj_t *parent) {
    /* 最後建立 ⇒ 疊在所有東西之上；平常隱藏。
     * ⚠️ 寬度必須是 SCR_W(280)，不是 240——原版寫死 240，右邊 40px 會漏出
     *    底下的面板。那是 2026-09-03 改版順手修掉的 bug 之一。 */
    cheat_panel = rl_rect(parent, 0, 0, SCR_W, SCR_H, PAL->bg, 0);
    lv_obj_add_flag(cheat_panel, LV_OBJ_FLAG_HIDDEN);

    cheat_title = rl_label(cheat_panel, 20, 14, &FR_Regular_48, PAL->accent, CHEAT_LAYER_NAME);
    cheat_sub   = rl_label(cheat_panel, 104, 32, &DINishCondensed_SemiBold_22, PAL->index, "SYMBOLS");
    cheat_rule  = rl_rect(cheat_panel, 20, 74, 240, 1, PAL->rule, 0);

    /* 兩手之間的細線，讓「哪五欄是右手」一眼看得出來 */
    cheat_divider = rl_rect(cheat_panel, CHEAT_DIV_X, CHEAT_Y0 - 6,
                            1, (CHEAT_ROWS - 1) * CHEAT_LINE_SP + CHEAT_FONT_LH + 12,
                            PAL->rule, 0);

    for (int col = 0; col < CHEAT_COLS * CHEAT_HANDS; col++) {
        char *dst = cheat_col_text[col];
        size_t len = 0;

        for (int row = 0; row < CHEAT_ROWS; row++) {
            const char *cell = cheat_cells[row][col];
            if (row > 0) {
                dst[len++] = '\n';
            }
            if (cell != NULL && cell[0] != '\0') {
                dst[len++] = cell[0];   /* 每格都是單一 ASCII 字元 */
            }
        }
        dst[len] = '\0';

        lv_coord_t x = (col < CHEAT_COLS)
                           ? CHEAT_X0 + col * CHEAT_CELL_W
                           : CHEAT_X1 + (col - CHEAT_COLS) * CHEAT_CELL_W;

        lv_obj_t *l = rl_label(cheat_panel, x, CHEAT_Y0,
                               &lv_font_unscii_16, PAL->name, dst);
        /* 固定寬度 + 置中：欄位對齊與字寬無關，而且一行只有 1 個字元，
         * 不管 long mode 是什麼都不可能 wrap。 */
        lv_obj_set_width(l, CHEAT_CELL_W);
        lv_obj_set_style_text_align(l, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
        lv_obj_set_style_text_line_space(l, CHEAT_LINE_SP - CHEAT_FONT_LH, LV_PART_MAIN);
        cheat_col_labels[col] = l;
    }
}

/* 大小寫不敏感、最多比 4 字元（廣播欄位長度）。 */
static bool cheat_name_match(const char *layer_name) {
    if (!layer_name) return false;
    size_t i = 0;
    for (; i < 4 && CHEAT_LAYER_NAME[i]; i++) {
        char c = layer_name[i];
        if (c >= 'a' && c <= 'z') c -= 32;
        if (c != CHEAT_LAYER_NAME[i]) return false;
    }
    return (i >= 4) || layer_name[i] == '\0';
}

static void update_cheat_panel(const char *layer_name) {
    if (!cheat_panel) return;

    bool show = layer_name && layer_name[0] && cheat_name_match(layer_name);
    bool hidden = lv_obj_has_flag(cheat_panel, LV_OBJ_FLAG_HIDDEN);
    if (show && hidden) {
        lv_obj_clear_flag(cheat_panel, LV_OBJ_FLAG_HIDDEN);
    } else if (!show && !hidden) {
        lv_obj_add_flag(cheat_panel, LV_OBJ_FLAG_HIDDEN);
    }
}

/* ========== 建立 ========== */

static void create_ladder(lv_obj_t *parent) {
    for (int i = 0; i < LAYER_COUNT; i++) {
        ticks[i] = rl_rect(parent, LADDER_X, LADDER_Y + i * LADDER_PITCH,
                        LADDER_W, TICK_H, PAL->rule, 1);
    }
}

static void create_text_column(lv_obj_t *parent) {
    index_label = rl_label(parent, TEXT_X + 2, 34, &DINishCondensed_SemiBold_22, PAL->index, "00");
    lv_obj_set_style_text_letter_space(index_label, 2, LV_PART_MAIN);

    /* 固定單行大字。刻意不設 width、不設 long mode ⇒ 不 wrap。 */
    name_label = rl_label(parent, TEXT_X, 62, &FR_Regular_48, PAL->name, "BASE");

    hrule = rl_rect(parent, TEXT_X, 126, 150, 1, PAL->rule, 0);

    sub1_label = rl_label(parent, TEXT_X, 136, &DINishCondensed_SemiBold_22, PAL->accent, "TYPING");
    sub2_label = rl_label(parent, TEXT_X, 164, &DINishCondensed_SemiBold_20, PAL->sub2, "13 layers");
}

static void create_right_column(lv_obj_t *parent) {
    vrule = rl_rect(parent, COL_X, LADDER_Y, 1, 188, PAL->rule, 0);

    /* 修飾鍵 2x2，Mac 符號。順序：CMD(GUI) / OPT(ALT) / CTRL / SHIFT */
    static const int mod_pos[4][2] = { {0, 30}, {30, 30}, {0, 64}, {30, 64} };
    static const char *mod_symbols[4] = {
        SYMBOL_COMMAND, SYMBOL_OPTION, SYMBOL_CONTROL, SYMBOL_SHIFT
    };
    for (int i = 0; i < 4; i++) {
        mod_labels[i] = rl_label(parent, RIGHT_X + mod_pos[i][0], mod_pos[i][1],
                              &Symbols_Semibold_28, PAL->mod_off, mod_symbols[i]);
    }

    /* 電量：左半(central) 在上，右半(peripheral) 在下 */
    static const char *tags[2] = { "L", "R" };
    static const int rows[2] = { 114, 150 };
    for (int i = 0; i < 2; i++) {
        bat_tag[i]   = rl_label(parent, RIGHT_X, rows[i] + 6,
                             &DINishCondensed_SemiBold_20, PAL->index, tags[i]);
        bat_value[i] = rl_label(parent, RIGHT_X + 14, rows[i],
                             &FG_Medium_21, PAL->value, "--");
        bat_bar_bg[i]   = rl_rect(parent, RIGHT_X, rows[i] + 26, BAR_W, BAR_H, PAL->rule, 1);
        bat_bar_fill[i] = rl_rect(parent, RIGHT_X, rows[i] + 26, 1, BAR_H, PAL->accent, 1);
        lv_obj_add_flag(bat_bar_fill[i], LV_OBJ_FLAG_HIDDEN);
    }

    /* BLE profile 四點（模組廣播的 profile slot 0-4，這裡畫 4 個） */
    for (int i = 0; i < 4; i++) {
        ble_dots[i] = rl_rect(parent, RIGHT_X + i * 12, 200, 8, 8, PAL->rule, 4);
    }
}

/* ========== 更新 ========== */

static void update_ladder(uint8_t active_layer) {
    for (int i = 0; i < LAYER_COUNT; i++) {
        if (!ticks[i]) continue;
        bool on = (i == active_layer);
        lv_obj_set_size(ticks[i], on ? TICK_ON_W : LADDER_W, on ? TICK_ON_H : TICK_H);
        lv_obj_set_pos(ticks[i],
                       on ? LADDER_X - 3 : LADDER_X,
                       LADDER_Y + i * LADDER_PITCH - (on ? 1 : 0));
        lv_obj_set_style_bg_color(ticks[i],
                                  lv_color_hex(on ? PAL->accent : PAL->rule), LV_PART_MAIN);
    }
}

static void update_modifiers(uint8_t flags) {
    /* HID flags: bit 0/4=Ctrl, 1/5=Shift, 2/6=Alt, 3/7=GUI */
    const bool mods[4] = {
        (flags & 0x88) != 0,  /* GUI  -> ⌘ */
        (flags & 0x44) != 0,  /* ALT  -> ⌥ */
        (flags & 0x11) != 0,  /* CTRL -> ⌃ */
        (flags & 0x22) != 0,  /* SHFT -> ⇧ */
    };
    for (int i = 0; i < 4; i++) {
        if (!mod_labels[i]) continue;
        lv_obj_set_style_text_color(mod_labels[i],
                                    lv_color_hex(mods[i] ? PAL->accent : PAL->mod_off),
                                    LV_PART_MAIN);
    }
}

static void update_battery(int slot, uint8_t level, bool connected) {
    if (!bat_value[slot]) return;

    if (connected && level > 0) {
        char buf[8];
        snprintf(buf, sizeof(buf), "%u", level);
        lv_label_set_text(bat_value[slot], buf);
        lv_obj_set_style_text_color(bat_value[slot], lv_color_hex(PAL->value), LV_PART_MAIN);

        int w = (int)level * BAR_W / 100;
        if (w < 1) w = 1;
        lv_obj_set_width(bat_bar_fill[slot], w);
        lv_obj_clear_flag(bat_bar_fill[slot], LV_OBJ_FLAG_HIDDEN);
    } else {
        lv_label_set_text(bat_value[slot], "--");
        lv_obj_set_style_text_color(bat_value[slot], lv_color_hex(PAL->index), LV_PART_MAIN);
        lv_obj_add_flag(bat_bar_fill[slot], LV_OBJ_FLAG_HIDDEN);
    }
}

static void update_ble(bool usb_connected, uint8_t ble_profile) {
    for (int i = 0; i < 4; i++) {
        if (!ble_dots[i]) continue;
        bool on = !usb_connected && (i == ble_profile);
        lv_obj_set_style_bg_color(ble_dots[i],
                                  lv_color_hex(on ? PAL->accent : PAL->rule), LV_PART_MAIN);
    }
}

/* ========== 套用調色盤 ========== */

static void apply_palette(void) {
    if (!layout_created) return;

    if (bg_obj)       lv_obj_set_style_bg_color(bg_obj, lv_color_hex(PAL->bg), LV_PART_MAIN);
    if (parent_screen) lv_obj_set_style_bg_color(parent_screen, lv_color_hex(PAL->bg), LV_PART_MAIN);
    if (name_label)   lv_obj_set_style_text_color(name_label, lv_color_hex(PAL->name), LV_PART_MAIN);
    if (index_label)  lv_obj_set_style_text_color(index_label, lv_color_hex(PAL->index), LV_PART_MAIN);
    if (sub1_label)   lv_obj_set_style_text_color(sub1_label, lv_color_hex(PAL->accent), LV_PART_MAIN);
    if (sub2_label)   lv_obj_set_style_text_color(sub2_label, lv_color_hex(PAL->sub2), LV_PART_MAIN);
    if (hrule)        lv_obj_set_style_bg_color(hrule, lv_color_hex(PAL->rule), LV_PART_MAIN);
    if (vrule)        lv_obj_set_style_bg_color(vrule, lv_color_hex(PAL->rule), LV_PART_MAIN);

    for (int i = 0; i < 2; i++) {
        if (bat_tag[i])     lv_obj_set_style_text_color(bat_tag[i], lv_color_hex(PAL->index), LV_PART_MAIN);
        if (bat_bar_bg[i])  lv_obj_set_style_bg_color(bat_bar_bg[i], lv_color_hex(PAL->rule), LV_PART_MAIN);
        if (bat_bar_fill[i])lv_obj_set_style_bg_color(bat_bar_fill[i], lv_color_hex(PAL->accent), LV_PART_MAIN);
    }

    if (cheat_panel) lv_obj_set_style_bg_color(cheat_panel, lv_color_hex(PAL->bg), LV_PART_MAIN);
    if (cheat_title) lv_obj_set_style_text_color(cheat_title, lv_color_hex(PAL->accent), LV_PART_MAIN);
    if (cheat_sub)   lv_obj_set_style_text_color(cheat_sub, lv_color_hex(PAL->index), LV_PART_MAIN);
    if (cheat_rule)  lv_obj_set_style_bg_color(cheat_rule, lv_color_hex(PAL->rule), LV_PART_MAIN);
    if (cheat_divider) lv_obj_set_style_bg_color(cheat_divider, lv_color_hex(PAL->rule), LV_PART_MAIN);
    for (int c = 0; c < CHEAT_COLS * CHEAT_HANDS; c++) {
        if (cheat_col_labels[c])
            lv_obj_set_style_text_color(cheat_col_labels[c], lv_color_hex(PAL->name), LV_PART_MAIN);
    }

    /* ladder / 修飾鍵 / BLE 的顏色跟狀態綁在一起，下一次 update 會刷到。 */
    LOG_INF("Applied palette: %s", PAL->pname);
}

/* ========== 公開 API ========== */

lv_obj_t *radii_layout_create(lv_obj_t *parent) {
    if (layout_created) {
        LOG_WRN("Radii layout already created");
        return parent;
    }

    parent_screen = parent;

    lv_obj_set_style_bg_color(parent, lv_color_hex(PAL->bg), LV_PART_MAIN);
    lv_obj_set_style_bg_opa(parent, LV_OPA_COVER, LV_PART_MAIN);

    bg_obj = rl_rect(parent, 0, 0, SCR_W, SCR_H, PAL->bg, 0);

    create_ladder(parent);
    create_text_column(parent);
    create_right_column(parent);
    create_cheat_panel(parent);   /* 一定要最後：z-order 蓋在其他東西上 */

    layout_created = true;
    current_layer = 0xFF;
    LOG_INF("Radii layout created (dashboard, %d layers, %s theme)",
            LAYER_COUNT, PAL->pname);
    return parent;
}

void radii_layout_update(uint8_t active_layer, const char *layer_name,
                         uint8_t battery_level, bool battery_connected,
                         uint8_t peripheral_battery, bool peripheral_connected,
                         uint8_t modifier_flags, bool usb_connected, uint8_t ble_profile) {
    if (!layout_created) return;

    bool known = (active_layer < LAYER_COUNT);

    if (active_layer != current_layer) {
        update_ladder(active_layer);

        /* index 兩位數 */
        if (index_label) {
            char buf[8];
            snprintf(buf, sizeof(buf), "%02u", active_layer);
            lv_label_set_text(index_label, buf);
        }

        /* 大字層名：優先用廣播帶來的（那是 keymap 的 display-name 本尊），
         * 空的才退回本地表，再不行才用 index。
         * 廣播欄位不保證 null-terminated，所以只複製 4 bytes 再自己補 0。 */
        if (name_label) {
            char name[5] = {0};
            if (layer_name && layer_name[0]) {
                memcpy(name, layer_name, 4);
                for (int i = 0; i < 4; i++) {
                    if (name[i] >= 'a' && name[i] <= 'z') name[i] -= 32;
                }
                lv_label_set_text(name_label, name);
            } else if (known) {
                lv_label_set_text(name_label, LAYERS[active_layer].name);
            } else {
                char buf[8];
                snprintf(buf, sizeof(buf), "L%u", active_layer);
                lv_label_set_text(name_label, buf);
            }
        }

        /* 副標：本地表，不受 4 bytes 限制 */
        if (sub1_label) lv_label_set_text(sub1_label, known ? LAYERS[active_layer].sub1 : "");
        if (sub2_label) lv_label_set_text(sub2_label, known ? LAYERS[active_layer].sub2 : "");

        current_layer = active_layer;
    }

    update_battery(0, battery_level, battery_connected);
    update_battery(1, peripheral_battery, peripheral_connected);
    update_modifiers(modifier_flags);
    update_ble(usb_connected, ble_profile);
    update_cheat_panel(layer_name);

    if (parent_screen) {
        lv_obj_invalidate(parent_screen);
    }
}

void radii_layout_destroy(void) {
    if (!layout_created) return;

    if (bg_obj)      { lv_obj_del(bg_obj);      bg_obj = NULL; }
    if (index_label) { lv_obj_del(index_label); index_label = NULL; }
    if (name_label)  { lv_obj_del(name_label);  name_label = NULL; }
    if (hrule)       { lv_obj_del(hrule);       hrule = NULL; }
    if (sub1_label)  { lv_obj_del(sub1_label);  sub1_label = NULL; }
    if (sub2_label)  { lv_obj_del(sub2_label);  sub2_label = NULL; }
    if (vrule)       { lv_obj_del(vrule);       vrule = NULL; }
    if (cheat_panel) { lv_obj_del(cheat_panel); cheat_panel = NULL; }

    cheat_title = NULL;
    cheat_sub = NULL;
    cheat_rule = NULL;
    cheat_divider = NULL;
    for (int c = 0; c < CHEAT_COLS * CHEAT_HANDS; c++) cheat_col_labels[c] = NULL;

    for (int i = 0; i < LAYER_COUNT; i++) {
        if (ticks[i]) { lv_obj_del(ticks[i]); ticks[i] = NULL; }
    }
    for (int i = 0; i < 4; i++) {
        if (mod_labels[i]) { lv_obj_del(mod_labels[i]); mod_labels[i] = NULL; }
        if (ble_dots[i])   { lv_obj_del(ble_dots[i]);   ble_dots[i] = NULL; }
    }
    for (int i = 0; i < 2; i++) {
        if (bat_tag[i])      { lv_obj_del(bat_tag[i]);      bat_tag[i] = NULL; }
        if (bat_value[i])    { lv_obj_del(bat_value[i]);    bat_value[i] = NULL; }
        if (bat_bar_bg[i])   { lv_obj_del(bat_bar_bg[i]);   bat_bar_bg[i] = NULL; }
        if (bat_bar_fill[i]) { lv_obj_del(bat_bar_fill[i]); bat_bar_fill[i] = NULL; }
    }

    parent_screen = NULL;
    layout_created = false;
    current_layer = 0xFF;

    LOG_INF("Radii layout destroyed");
}

void radii_layout_cycle_palette(void) {
    if (!layout_created) return;
    current_palette = (current_palette + 1) % PALETTE_COUNT;
    apply_palette();
    current_layer = 0xFF;   /* 強制下一次 update 重刷 ladder / 層名顏色 */
}

uint8_t radii_layout_get_palette(void) {
    return current_palette;
}

const char *radii_layout_get_palette_name(void) {
    return color_palettes[current_palette].pname;
}
