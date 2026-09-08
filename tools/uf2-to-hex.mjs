/*
 * UF2 -> Intel HEX。給序列 DFU 用的。
 *
 * 為什麼需要這個：這台 Windows 被公司 GPO（HKCU\...\RemovableStorageDevices
 * Deny_All = 1）擋掉所有卸除式儲存，UF2 bootloader 的磁碟掛不上，拖不進去。
 * 改走 bootloader 的序列 DFU（COM port，不是隨身碟），而 adafruit-nrfutil
 * 的 genpkg 只吃 .hex，所以要先把 CI 產出的 .uf2 轉過來。
 *
 * UF2 格式：固定 512 bytes 一塊，32 bytes 標頭 + 476 bytes 資料 + 尾端 magic。
 * 規格見 https://github.com/microsoft/uf2
 *
 *   node tools/uf2-to-hex.mjs <in.uf2> <out.hex>
 */
import fs from 'fs';

const MAGIC0 = 0x0a324655, MAGIC1 = 0x9e5d5157, MAGIC_END = 0x0ab16f30;
const F_NOT_MAIN_FLASH = 0x00000001, F_FILE_CONTAINER = 0x00001000, F_FAMILY_ID = 0x00002000;

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) { console.error('用法: node tools/uf2-to-hex.mjs <in.uf2> <out.hex>'); process.exit(2); }

const buf = fs.readFileSync(inPath);
if (buf.length % 512 !== 0) { console.error(`不是合法的 UF2：長度 ${buf.length} 不是 512 的倍數`); process.exit(1); }

const chunks = [];               // { addr, data }
let skipped = 0, families = new Set(), total = null;
for (let off = 0; off < buf.length; off += 512) {
    if (buf.readUInt32LE(off) !== MAGIC0 || buf.readUInt32LE(off + 4) !== MAGIC1
        || buf.readUInt32LE(off + 508) !== MAGIC_END) {
        console.error(`第 ${off / 512} 塊的 magic 不對，檔案可能損毀`); process.exit(1);
    }
    const flags = buf.readUInt32LE(off + 8);
    const addr = buf.readUInt32LE(off + 12);
    const size = buf.readUInt32LE(off + 16);
    const numBlocks = buf.readUInt32LE(off + 24);
    const familyOrLen = buf.readUInt32LE(off + 28);
    if (total === null) total = numBlocks;
    if (flags & F_FAMILY_ID) families.add('0x' + familyOrLen.toString(16));
    if ((flags & F_NOT_MAIN_FLASH) || (flags & F_FILE_CONTAINER)) { skipped++; continue; }
    if (size > 476) { console.error(`第 ${off / 512} 塊的 payloadSize ${size} > 476`); process.exit(1); }
    chunks.push({ addr, data: buf.subarray(off + 32, off + 32 + size) });
}
if (!chunks.length) { console.error('沒有可燒錄的資料'); process.exit(1); }

chunks.sort((a, b) => a.addr - b.addr);
for (let i = 1; i < chunks.length; i++) {
    if (chunks[i].addr < chunks[i - 1].addr + chunks[i - 1].data.length) {
        console.error(`區塊位址重疊：0x${chunks[i - 1].addr.toString(16)} 與 0x${chunks[i].addr.toString(16)}`);
        process.exit(1);
    }
}

const lines = [];
const rec = (len, addr, type, data) => {
    const b = [len, (addr >> 8) & 0xff, addr & 0xff, type, ...data];
    const sum = (0x100 - (b.reduce((a, c) => a + c, 0) & 0xff)) & 0xff;
    lines.push(':' + [...b, sum].map(x => x.toString(16).toUpperCase().padStart(2, '0')).join(''));
};

let upper = -1;
for (const { addr, data } of chunks) {
    for (let i = 0; i < data.length; i += 16) {
        const a = addr + i;
        const hi = (a >>> 16) & 0xffff;
        if (hi !== upper) { rec(2, 0, 4, [(hi >> 8) & 0xff, hi & 0xff]); upper = hi; }
        const row = data.subarray(i, Math.min(i + 16, data.length));
        rec(row.length, a & 0xffff, 0, [...row]);
    }
}
rec(0, 0, 1, []);
fs.writeFileSync(outPath, lines.join('\n') + '\n');

const bytes = chunks.reduce((a, c) => a + c.data.length, 0);
const lo = chunks[0].addr, hi = chunks[chunks.length - 1].addr + chunks[chunks.length - 1].data.length - 1;
console.log(`UF2 ${buf.length / 512} 塊（標頭宣告 ${total}）` + (skipped ? `，略過 ${skipped} 塊非快閃資料` : ''));
console.log(`family: ${[...families].join(',') || '(未標示)'}`);
console.log(`位址範圍 0x${lo.toString(16)} - 0x${hi.toString(16)}，共 ${bytes} bytes`);
console.log(`已寫出 ${outPath}（${lines.length} 筆 HEX 記錄）`);
