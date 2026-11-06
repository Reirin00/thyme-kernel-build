#!/usr/bin/env python3
"""给 fs/proc/base.c 补上 <linux/susfs_def.h> 的 include。

背景：
  打 simonpunk 的 50_add_susfs_in_gki-android15-6.6.patch 时，
  fs/proc/base.c 有 4 个 hunk，其中 3 个成功（把
  SUSFS_IS_INODE_OPEN_REDIRECT / SUSFS_IS_INODE_SUS_MAP 的调用点插进去了），
  只有加 include 的那一个失败了。

  结果就是：调用点在、宏没声明 → 编译报
    error: call to undeclared function 'SUSFS_IS_INODE_OPEN_REDIRECT'

  这里把 include 手工补回去。susfs_def.h 自带 include guard，重复包含无害。

用法：
  python3 patches/fix_base_include.py fs/proc/base.c
"""

import sys

MARK = '#include <linux/susfs_def.h>'
INC = '#include <linux/susfs_def.h>'


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'fs/proc/base.c'
    try:
        src = open(path, encoding='utf-8').read()
    except FileNotFoundError:
        print('  [skip] %s 不存在' % path)
        return 0

    if MARK in src:
        print('  [ok] %s 已有 susfs_def.h' % path)
        return 0

    lines = src.split('\n')

    # 首选：插在 '#include <linux/dma-buf.h>' 后面（补丁原本的位置）
    for i, line in enumerate(lines):
        if line.strip() == '#include <linux/dma-buf.h>':
            lines.insert(i + 1, INC)
            open(path, 'w', encoding='utf-8').write('\n'.join(lines))
            print('  [ok] 已在 dma-buf.h 之后插入 susfs_def.h（第 %d 行）' % (i + 2))
            return 0

    # 兜底：插在文件里最后一个 '#include <linux/' 之后
    last = None
    for i, line in enumerate(lines):
        if line.strip().startswith('#include <linux/'):
            last = i
    if last is not None:
        lines.insert(last + 1, INC)
        open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        print('  [ok] 已在最后一个 linux/ 头文件之后插入（第 %d 行）' % (last + 2))
        return 0

    print('  [fail] 找不到合适的插入点')
    return 1


if __name__ == '__main__':
    sys.exit(main())
