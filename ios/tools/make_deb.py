# -*- coding: utf-8 -*-
"""打包 roothide scheme 的 .deb：data 里是相对路径 Applications/ZCodeRemote.app，
由 RootHide dpkg 映射到 /var/jb/Applications（用户手机 Relaxin 越狱的既定事实）。
不依赖 dpkg-deb（macOS runner 没有）：纯 Python 生成 control/data tar.gz，
再手写 ar 归档拼成 .deb。

用法：python3 ios/tools/make_deb.py <ZCodeRemote.app> <输出目录> [--version 0.0.2-ios1]
"""
import argparse
import hashlib
import io
import os
import tarfile
import time

NAME = "ZCodeRemote"
PACKAGE = "com.zcode.remote"
FIXED_MTIME = 1700000000  # 固定时间戳,产物可复现


def add_file(tar: tarfile.TarFile, arcname: str, path: str, executable: bool = False) -> bytes:
    with open(path, "rb") as f:
        data = f.read()
    info = tarfile.TarInfo(arcname)
    info.size = len(data)
    info.mtime = FIXED_MTIME
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "wheel"
    info.mode = 0o755 if executable else 0o644
    tar.addfile(info, io.BytesIO(data))
    return data


def add_bytes(tar: tarfile.TarFile, arcname: str, data: bytes, executable: bool = False) -> None:
    info = tarfile.TarInfo(arcname)
    info.size = len(data)
    info.mtime = FIXED_MTIME
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "wheel"
    info.mode = 0o755 if executable else 0o644
    tar.addfile(info, io.BytesIO(data))


POSTINST = """#!/bin/sh
# roothide: /var/jb/Applications；rootful 兜底: /Applications。注册到 SpringBoard。
APP=""
[ -d /var/jb/Applications/%NAME%.app ] && APP=/var/jb/Applications/%NAME%.app
[ -z "$APP" ] && [ -d /Applications/%NAME%.app ] && APP=/Applications/%NAME%.app
UC=""
[ -x /var/jb/usr/bin/uicache ] && UC=/var/jb/usr/bin/uicache
[ -z "$UC" ] && [ -x /usr/bin/uicache ] && UC=/usr/bin/uicache
[ -z "$UC" ] && UC="$(command -v uicache 2>/dev/null)"
if [ -n "$APP" ] && [ -n "$UC" ]; then
  "$UC" -p "$APP" || true
fi
exit 0
""".replace("%NAME%", NAME)

POSTRM = """#!/bin/sh
APP=""
[ -d /var/jb/Applications/%NAME%.app ] && APP=/var/jb/Applications/%NAME%.app
[ -z "$APP" ] && [ -d /Applications/%NAME%.app ] && APP=/Applications/%NAME%.app
UC=""
[ -x /var/jb/usr/bin/uicache ] && UC=/var/jb/usr/bin/uicache
[ -z "$UC" ] && [ -x /usr/bin/uicache ] && UC=/usr/bin/uicache
[ -z "$UC" ] && UC="$(command -v uicache 2>/dev/null)"
if [ -n "$APP" ] && [ -n "$UC" ]; then
  "$UC" -u "$APP" || true
fi
exit 0
""".replace("%NAME%", NAME)


def build_data_tar(app_path: str) -> tuple[bytes, list[str]]:
    buf = io.BytesIO()
    hashes = []
    with tarfile.open(fileobj=buf, mode="w:gz", format=tarfile.GNU_FORMAT) as tar:
        # Applications/ZCodeRemote.app/**（相对路径 = roothide scheme）
        for base, dirs, files in os.walk(app_path):
            dirs.sort()
            files.sort()
            for n in dirs:
                full = os.path.join(base, n)
                arc = "./Applications/" + NAME + ".app/" + os.path.relpath(full, app_path).replace("\\", "/")
                info = tarfile.TarInfo(arc)
                info.type = tarfile.DIRTYPE
                info.mode = 0o755
                info.mtime = FIXED_MTIME
                info.uid = 0
                info.gid = 0
                info.uname = "root"
                info.gname = "wheel"
                tar.addfile(info)
            for n in files:
                full = os.path.join(base, n)
                rel = os.path.relpath(full, app_path).replace("\\", "/")
                arc = "./Applications/" + NAME + ".app/" + rel
                data = add_file(tar, arc, full)
                hashes.append((hashlib.md5(data).hexdigest(), arc[2:]))
    return buf.getvalue(), hashes


def build_control_tar(app_path: str, version: str, hashes: list[tuple[str, str]]) -> bytes:
    size_kb = 0
    for base, _, files in os.walk(app_path):
        for n in files:
            size_kb += os.path.getsize(os.path.join(base, n)) // 1024
    size_kb += 1
    control = (
        f"Package: {PACKAGE}\n"
        f"Name: {NAME}\n"
        f"Version: {version}\n"
        "Architecture: iphoneos-arm64e\n"
        "Description: ZCode 手机远控增强客户端（iOS 版）。包装官方远控网页：注入增强层/回复通知/后台保活/扫码进入。\n"
        "Author: liudubin\n"
        "Maintainer: liudubin <liudubin@users.noreply.github.com>\n"
        "Section: Utilities\n"
        "Depends: firmware (>= 15.0)\n"
        f"Installed-Size: {size_kb}\n"
    ).encode("utf-8")

    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz", format=tarfile.GNU_FORMAT) as tar:
        add_bytes(tar, "./control", control)
        add_bytes(tar, "./postinst", POSTINST.encode("utf-8"), executable=True)
        add_bytes(tar, "./postrm", POSTRM.encode("utf-8"), executable=True)
        md5 = "".join("%s  %s\n" % (h, p) for h, p in sorted(hashes))
        add_bytes(tar, "./md5sums", md5.encode("utf-8"))
    return buf.getvalue()


def ar_write(out_path: str, members: list[tuple[str, bytes]]) -> None:
    out = b"!<arch>\n"
    for name, data in members:
        header = name.ljust(16)
        header += str(FIXED_MTIME).ljust(12)
        header += "0".ljust(6) + "0".ljust(6)
        header += "100644".ljust(8)
        header += str(len(data)).ljust(10)
        header += "`\n"
        out += header.encode("ascii")
        out += data
        if len(data) % 2:
            out += b"\n"
    with open(out_path, "wb") as f:
        f.write(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("app")
    ap.add_argument("outdir")
    ap.add_argument("--version", default="0.0.2-ios1")
    args = ap.parse_args()

    data_gz, hashes = build_data_tar(args.app)
    control_gz = build_control_tar(args.app, args.version, hashes)

    os.makedirs(args.outdir, exist_ok=True)
    out = os.path.join(args.outdir, f"{PACKAGE}_{args.version}_iphoneos-arm64e.deb")
    ar_write(out, [
        ("debian-binary", b"2.0\n"),
        ("control.tar.gz", control_gz),
        ("data.tar.gz", data_gz),
    ])
    print("deb written: %s (%d bytes, %d files)" % (out, os.path.getsize(out), len(hashes)))


if __name__ == "__main__":
    main()
