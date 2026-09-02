#include <zephyr/kernel.h>
#include <string.h>

#include "cheatsheet.h"
#include "../assets/custom_fonts.h"
#include <zmk/keymap.h>

/*
 * 按鍵小抄。
 *
 * 為什麼要有：SYMBOL 層有 30 個符號，記不住是常態。左半升成 split central
 * 之後螢幕才拿得到層資訊（nice_view_gem 的 CMakeLists 只在 central 才編
 * layer.c / screen.c），順手把小抄一起做掉。
 *
 * ── 維護方式 ──────────────────────────────────────────────────────────
 * 這是手寫表，「不會」自動跟 config/toucan.keymap 同步。改了 SYMBOL 層的
 * bindings 就要回來改這裡，否則螢幕會騙人。
 *
 * 對照關係是鍵位 index（見 config/toucan.keymap 檔頭的圖）：
 *   row[0] = 位置 1-5   ｜ 6-10
 *   row[1] = 位置 13-17 ｜ 18-22
 *   row[2] = 位置 25-29 ｜ 30-34
 * 位置 0/11/12/23/24/35 沒焊開關，不在表內；拇指 36-41 也沒畫——垂直空間
 * 只夠三排（見下面的座標說明），而拇指只有三顆符號鍵，比整片格子好記。
 *
 * 用「層名」而不是層號比對，是因為 ZMK Studio 可以重排層序，寫死 index 3
 * 會在重排後指到別層。層名來自 keymap 的 display-name。
 */

#define CHEAT_COLS 5    /* 每隻手 5 欄 */
#define CHEAT_ROWS 3

struct cheat_sheet {
    const char *layer_name;
    /* [排][欄]，左手 0-4、右手 5-9。空字串 = 那顆不是符號（例如純 modifier）。 */
    const char *cell[CHEAT_ROWS][CHEAT_COLS * 2];
};

static const struct cheat_sheet sheets[] = {
    {
        .layer_name = "SYM", /* = keymap 裡該層的 display-name，改名要同步 */
        .cell =
            {
                /* 位置  1    2    3    4    5  ｜   6    7    8    9   10 */
                {"?", "!", "[", "]", "+", "@", "#", "$", "\"", "`"},
                /* 位置 13   14   15   16   17  ｜  18   19   20   21   22 */
                /* 20/21 是 LGUI/LCTRL，純 modifier，留白 */
                {"<", ">", "(", ")", "-", "~", "'", "", "", ":"},
                /* 位置 25   26   27   28   29  ｜  30   31   32   33   34 */
                {"|", "&", "{", "}", "=", "^", "*", ",", "\\", "/"},
            },
    },
};

/*
 * 版面座標。這塊空白帶是實測出來的——上面 y70-94 是層名（quinquefive_24），
 * 下面 y140 是 USB/BLE、y143 是 profile 點。中間 y96-138 沒人用。
 *
 * 每格單獨畫（而不是把一排併成一個字串），是為了讓欄位對齊跟字寬無關：
 * 每一格都對應一顆實體鍵，格子必須等寬，字元本身寬窄不該影響位置。
 */
#define CHEAT_CELL_W 13
#define CHEAT_CELL_H 13
#define CHEAT_X0      2                                        /* 左手第一欄 */
#define CHEAT_GUTTER 10                                        /* 兩手之間的溝 */
#define CHEAT_X1     (CHEAT_X0 + CHEAT_COLS * CHEAT_CELL_W + CHEAT_GUTTER)  /* 77 */
#define CHEAT_Y0     98

static const struct cheat_sheet *find_sheet(const char *layer_name) {
    if (layer_name == NULL || layer_name[0] == '\0') {
        return NULL;
    }

    for (size_t i = 0; i < ARRAY_SIZE(sheets); i++) {
        if (strcmp(sheets[i].layer_name, layer_name) == 0) {
            return &sheets[i];
        }
    }

    return NULL;
}

void draw_cheatsheet(lv_obj_t *canvas, const struct status_state *state) {
    const char *layer_name =
        zmk_keymap_layer_name(zmk_keymap_layer_index_to_id(state->layer_index));

    const struct cheat_sheet *sheet = find_sheet(layer_name);
    if (sheet == NULL) {
        return;
    }

    lv_draw_label_dsc_t label_dsc;
    init_label_dsc(&label_dsc, LVGL_FOREGROUND, &quinquefive_8, LV_TEXT_ALIGN_CENTER);

    for (int row = 0; row < CHEAT_ROWS; row++) {
        for (int col = 0; col < CHEAT_COLS * 2; col++) {
            const char *cell = sheet->cell[row][col];
            if (cell == NULL || cell[0] == '\0') {
                continue;
            }

            lv_coord_t x = (col < CHEAT_COLS) ? CHEAT_X0 + col * CHEAT_CELL_W
                                              : CHEAT_X1 + (col - CHEAT_COLS) * CHEAT_CELL_W;
            lv_coord_t y = CHEAT_Y0 + row * CHEAT_CELL_H;

            lv_canvas_draw_text(canvas, x, y, CHEAT_CELL_W, &label_dsc, cell);
        }
    }
}
