/*
 * Copyright (c) 2024 The ZMK Contributors
 * SPDX-License-Identifier: MIT
 *
 * Radii Layout for Scanner Mode
 *
 * 原本是 carrefinho feat/new-status-screens 的 port（輪盤 + 大字層名）。
 * 2026-09-03 在這個 fork 裡重寫成 Toucan 專用的「儀表板」——動機、版面座標
 * 與層名表都寫在 radii_layout.c 的檔頭。
 *
 * Features:
 * - 左緣 17 格 ladder（一格一層，取代裝不下 17 層的 10 格輪盤）
 * - 大字層名固定 4 字元單行 + 兩行本地副標（不受廣播 4 bytes 限制）
 * - 電量數字 + bar；Mac 修飾鍵符號（⌘, ⌥, ⌃, ⇧）；BLE profile 四點
 * - SYM 全螢幕按鍵小抄 overlay
 * - 4 組暗色調色盤：Mint / Amber / Ice / Rose
 *
 * API 與上游相同，prospector_layouts.c 不用改。
 */

#pragma once

#include <lvgl.h>

/* Radii layout API */
lv_obj_t *radii_layout_create(lv_obj_t *parent);
void radii_layout_update(uint8_t active_layer, const char *layer_name,
                        uint8_t battery_level, bool battery_connected,
                        uint8_t peripheral_battery, bool peripheral_connected,
                        uint8_t modifier_flags, bool usb_connected, uint8_t ble_profile);
void radii_layout_destroy(void);

/* Color palette cycling (Blue -> Green -> Red -> Purple -> Blue) */
void radii_layout_cycle_palette(void);
uint8_t radii_layout_get_palette(void);
const char *radii_layout_get_palette_name(void);
