#!/usr/bin/env python3
"""给 4.19 内核补 path_umount。

为什么需要：
  KernelSU 的 kernel/Makefile 会用 sed 把 path_umount 插到 fs/namespace.c 里
  'static bool is_mnt_ns_file' 之前，但那个实现依赖 can_umount()——5.9 才引入的
  权限检查函数，4.19 根本没有。而且：
    · $(shell sed -i ...) 失败不会让 make 报错，$(info) 只是打印一行"adding ..."
    · drivers/ 在 fs/ 之后编译，此时 fs/namespace.o 早已生成，就算真插进去也不重编
  所以链接期必然 undefined symbol: path_umount。

做法：
  用 4.19 自己有的 do_umount()（fs/namespace.c:1691，内部已含 may_umount 检查），
  跳过 5.9 的 can_umount()。插入点在 is_mnt_ns_file 之前，do_umount 已在上方定义。

为什么可以跳过 can_umount：
  can_umount() 在 5.9 里做的是 MNT_LOCKED / 用户命名空间 / 权限的三重检查，
  是给普通用户调 umount2 用的。这里的调用方是 KernelSU 自己（内核态、root cred），
  只 umount 它自己挂上去的 /system、/vendor、/data/adb/modules 等路径，
  do_umount 内部的 may_umount 检查足够。
"""

import sys

IMPL = '''int path_umount(struct path *path, int flags)
{
	struct mount *mnt = real_mount(path->mnt);
	int ret;

	ret = do_umount(mnt, flags);
	dput(path->dentry);
	mntput_no_expire(mnt);
	return ret;
}

'''

DECL = 'int path_umount(struct path *path, int flags);\n'


def main():
    ns_path = sys.argv[1] if len(sys.argv) > 1 else 'fs/namespace.c'
    ih_path = sys.argv[2] if len(sys.argv) > 2 else 'fs/internal.h'

    src = open(ns_path, encoding='utf-8').read()
    if 'int path_umount(struct path *path, int flags)' in src:
        print('  path_umount 已存在，跳过')
    else:
        anchor = 'static bool is_mnt_ns_file(struct dentry *dentry)'
        if anchor not in src:
            sys.exit('  !! 在 %s 里找不到锚点 %r' % (ns_path, anchor))
        src = src.replace(anchor, IMPL + anchor, 1)
        open(ns_path, 'w', encoding='utf-8').write(src)
        print('  [OK] fs/namespace.c 已补 path_umount（走 do_umount）')

    ih = open(ih_path, encoding='utf-8').read()
    if 'int path_umount' in ih:
        print('  internal.h 已有声明')
    else:
        mnt_init = 'extern void __init mnt_init(void);'
        if mnt_init in ih:
            ih = ih.replace(mnt_init, mnt_init + '\n' + DECL.rstrip('\n'), 1)
            open(ih_path, 'w', encoding='utf-8').write(ih)
            print('  [OK] fs/internal.h 已加声明')
        else:
            # 兜底：直接追加
            open(ih_path, 'a', encoding='utf-8').write('\n' + DECL)
            print('  [OK] fs/internal.h 已追加声明（兜底）')


if __name__ == '__main__':
    main()
