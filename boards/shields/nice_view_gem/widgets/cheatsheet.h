#pragma once

#include <lvgl.h>
#include "util.h"

/*
 * 在螢幕中段畫出目前這一層的按鍵小抄（3 排 x 10 欄，對應實體鍵位）。
 * 只有在 cheatsheet.c 的表格裡有登記的層才會畫，其餘層什麼都不做。
 */
void draw_cheatsheet(lv_obj_t *canvas, const struct status_state *state);
