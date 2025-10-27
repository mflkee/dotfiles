#!/usr/bin/env python3
# export_llm.py
# Собирает дерево проекта и контент текстовых файлов в единый Markdown и копирует в буфер обмена.

import os, sys, re, argparse, datetime, subprocess, shutil, mimetypes

DEFAULT_EXCLUDE_DIRS = {
    ".git", ".hg", ".svn", ".idea", ".vscode", ".tox", ".mypy_cache", ".ruff_cache", ".pytest_cache",
    "__pycache__", "node_modules", "dist", "build", "out", ".next", ".nuxt", ".svelte-kit",
    "target", ".cargo", "venv", ".venv", "env", ".env", ".pnpm-store", ".yarn", ".gradle",
    "DerivedData", "Pods", "Library", ".terraform", ".serverless", ".vercel",
    ".DS_Store"
}

# Базовый набор «текстовых» расширений
DEFAULT_TEXT_EXT = {
    # код
    ".py",".ipynb",".js",".ts",".tsx",".jsx",".mjs",".cjs",".vue",".svelte",".rb",".php",".java",".kt",".kts",
    ".cs",".go",".rs",".c",".h",".cpp",".hpp",".hh",".m",".mm",".swift",".scala",".hs",".rlib",".sh",".bash",".zsh",".fish",
    # данные/конфиги
    ".json",".jsonc",".yaml",".yml",".toml",".ini",".env",".properties",".cfg",
    ".lock",".sum",".gradle",".mod",".sum",".plist",
    # разметка/доки
    ".md",".mdx",".rst",".adoc",".txt",".org",".csv",".tsv",".sql",".graphql",".gql",".proto",
    # фронтенд ассеты текстовые
    ".css",".scss",".sass",".less",".postcss",
    # шаблоны/инфра
    ".tf",".tfvars",".dockerfile",".dockerignore",".gitignore",".gitattributes",".editorconfig","Makefile","makefile",
    "Dockerfile","Justfile","Procfile","CMakeLists.txt","cmake"
}

# Язык для подсветки по расширению (для удобства LLM)
LANG_HINT = {
    ".py":"python",".js":"javascript",".ts":"typescript",".tsx":"tsx",".jsx":"jsx",".mjs":"javascript",".cjs":"javascript",
    ".rb":"ruby",".php":"php",".java":"java",".kt":"kotlin",".kts":"kotlin",".cs":"csharp",".go":"go",".rs":"rust",
    ".c":"c",".h":"c",".cpp":"cpp",".hpp":"cpp",".hh":"cpp",".m":"objectivec",".mm":"objectivec",
    ".swift":"swift",".scala":"scala",".hs":"haskell",".sh":"bash",".bash":"bash",".zsh":"bash",".fish":"bash",
    ".json":"json",".jsonc":"json",".yaml":"yaml",".yml":"yaml",".toml":"toml",".ini":"ini",".env":"ini",
    ".md":"markdown",".mdx":"markdown",".rst":"rst",".adoc":"asciidoc",".txt":"text",".org":"org",
    ".csv":"csv",".tsv":"csv",".sql":"sql",".graphql":"graphql",".gql":"graphql",".proto":"proto",
    ".css":"css",".scss":"scss",".sass":"sass",".less":"less",".postcss":"css",
    ".tf":"hcl",".tfvars":"hcl",".dockerfile":"dockerfile",".dockerignore":"gitignore",".gitignore":"gitignore",
}

BIN_SIGNATURES = [b"\x00"]  # Нуль-байт — быстрый детектор бинарников

def is_probably_text(path: str, max_mb: float) -> bool:
    try:
        size = os.path.getsize(path)
        if size > max_mb * 1024 * 1024:
            return False
        with open(path, "rb") as f:
            chunk = f.read(4096)
            if any(sig in chunk for sig in BIN_SIGNATURES):
                return False
        # MIME эвристика
        mime, _ = mimetypes.guess_type(path)
        if mime and (mime.startswith("text/") or "json" in mime or "xml" in mime):
            return True
        # Фоллбэк: пробуем декодировать UTF-8
        try:
            chunk.decode("utf-8")
            return True
        except UnicodeDecodeError:
            return False
    except Exception:
        return False

def read_gitignore_patterns(root: str):
    p = os.path.join(root, ".gitignore")
    patterns = []
    if os.path.isfile(p):
        try:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    patterns.append(line)
        except Exception:
            pass
    return patterns

def match_gitignore(relpath: str, patterns):
    # Очень простая реализация: fnmatch по каждой строке
    import fnmatch
    rel = relpath.replace("\\", "/")
    for pat in patterns:
        # Поддержка игнора каталогов "dir/"
        if pat.endswith("/"):
            if rel.startswith(pat.rstrip("/")) or rel.split("/")[0] == pat.rstrip("/"):
                return True
        # Обычные паттерны
        if fnmatch.fnmatch(rel, pat) or fnmatch.fnmatch(os.path.basename(rel), pat):
            return True
    return False

def build_tree(paths, root):
    # Создаём красивое дерево (без зависимости от `tree`)
    from collections import defaultdict
    sep = os.sep
    root = os.path.abspath(root)
    nodes = defaultdict(list)
    for p in paths:
        d = os.path.dirname(p)
        nodes[d].append(os.path.basename(p))

    lines = []
    def walk(d, prefix=""):
        items = sorted(nodes.get(d, []))
        # Добавляем подкаталоги (получим их из всех путей)
        subdirs = sorted({os.path.dirname(pp) for pp in paths if os.path.dirname(pp).startswith(d + sep)})
        direct_subdirs = sorted({sd for sd in subdirs if os.path.dirname(sd) == d})
        entries = [("D", os.path.basename(sd)) for sd in direct_subdirs] + [("F", it) for it in items]
        for i, (t, name) in enumerate(entries):
            connector = "└── " if i == len(entries)-1 else "├── "
            line = f"{prefix}{connector}{name}{'/' if t=='D' else ''}"
            if line not in lines:
                lines.append(line)
            if t == "D":
                newd = os.path.join(d, name)
                newprefix = f"{prefix}{'    ' if i == len(entries)-1 else '│   '}"
                walk(newd, newprefix)
    lines.append(os.path.basename(root) + "/")
    walk(root, "")
    return "\n".join(lines)

def ext_of(path):
    base = os.path.basename(path)
    if base in LANG_HINT:
        return base  # Makefile, CMakeLists.txt etc.
    return os.path.splitext(path)[1].lower()

def lang_for(path):
    ext = ext_of(path)
    return LANG_HINT.get(ext, "")

def try_copy_to_clipboard(text: str) -> bool:
    # 1) pyperclip
    try:
        import pyperclip  # type: ignore
        pyperclip.copy(text)
        return True
    except Exception:
        pass
    # 2) Wayland wl-copy
    if shutil.which("wl-copy"):
        try:
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
            p.communicate(text.encode("utf-8"))
            return p.returncode == 0
        except Exception:
            pass
    # 3) xclip (X11)
    if shutil.which("xclip"):
        try:
            p = subprocess.Popen(["xclip", "-selection", "clipboard"], stdin=subprocess.PIPE)
            p.communicate(text.encode("utf-8"))
            return p.returncode == 0
        except Exception:
            pass
    # 4) xsel
    if shutil.which("xsel"):
        try:
            p = subprocess.Popen(["xsel", "--clipboard", "--input"], stdin=subprocess.PIPE)
            p.communicate(text.encode("utf-8"))
            return p.returncode == 0
        except Exception:
            pass
    # 5) macOS pbcopy
    if shutil.which("pbcopy"):
        try:
            p = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
            p.communicate(text.encode("utf-8"))
            return p.returncode == 0
        except Exception:
            pass
    # 6) Windows clip
    if os.name == "nt":
        try:
            p = subprocess.Popen("clip", stdin=subprocess.PIPE, shell=True)
            p.communicate(text.encode("utf-16-le"))
            return p.returncode == 0
        except Exception:
            pass
    return False

def main():
    ap = argparse.ArgumentParser(description="Экспорт проекта в удобный для LLM Markdown.")
    ap.add_argument("root", nargs="?", default=".", help="Корень проекта (по умолчанию текущая папка).")
    ap.add_argument("--max-mb", type=float, default=1.5, help="Максимальный размер одного файла в MB (по умолчанию 1.5).")
    ap.add_argument("--include-ext", type=str, default="", help="Доп. расширения через запятую (например: .rs,.go).")
    ap.add_argument("--exclude-dir", type=str, default="", help="Доп. исключаемые папки через запятую.")
    ap.add_argument("--no-clipboard", action="store_true", help="Не копировать в буфер обмена.")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        print(f"Нет такой директории: {root}", file=sys.stderr)
        sys.exit(1)

    include_ext = {e.strip().lower() for e in args.include_ext.split(",") if e.strip()}
    exclude_dirs = set(DEFAULT_EXCLUDE_DIRS)
    exclude_dirs |= {d.strip() for d in args.exclude_dir.split(",") if d.strip()}

    gitignore_patterns = read_gitignore_patterns(root)

    all_files = []
    for dirpath, dirnames, filenames in os.walk(root):
        # фильтруем каталоги на месте (ускорение os.walk)
        dirnames[:] = [d for d in dirnames if d not in exclude_dirs and not match_gitignore(os.path.relpath(os.path.join(dirpath, d), root), gitignore_patterns)]
        for fn in filenames:
            rel = os.path.relpath(os.path.join(dirpath, fn), root)
            if match_gitignore(rel, gitignore_patterns):
                continue
            all_files.append(os.path.join(dirpath, fn))

    # Фильтрация текстовых файлов
    selected = []
    for p in all_files:
        if os.path.islink(p):
            continue
        ext = ext_of(p)
        if ext in DEFAULT_TEXT_EXT or ext in include_ext:
            if is_probably_text(p, args.max_mb):
                selected.append(p)
        else:
            # если неизвестное расширение — попытаемся всё равно (но отфильтруем бинарники)
            if is_probably_text(p, args.max_mb):
                selected.append(p)

    # Строим дерево только по выбранным файлам
    # Чтобы дерево выглядело логично, добавим их родительские пути
    paths_for_tree = set()
    for p in selected:
        paths_for_tree.add(os.path.dirname(p))
        paths_for_tree.add(p)
    tree_text = build_tree(sorted(paths_for_tree), root)

    # Сбор Markdown
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    header = f"# Project Export for LLM\n\n- Root: `{root}`\n- Generated: {ts}\n- Files included: {len(selected)}\n- Per-file limit: {args.max_mb} MB\n\n## Project Tree\n\n```\n{tree_text}\n```\n\n## Files\n"
    parts = [header]

    for i, path in enumerate(sorted(selected), 1):
        rel = os.path.relpath(path, root)
        lang = lang_for(path)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
        except Exception as e:
            content = f"<<Ошибка чтения: {e}>>"
        parts.append(f"\n### {i}. `{rel}`\n\n```{lang}\n{content}\n```\n")

    result = "".join(parts)

    # Пишем в файл на диске
    out_path = os.path.join(root, "_llm_export.md")
    try:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(result)
    except Exception as e:
        print(f"Не удалось записать файл результата: {e}", file=sys.stderr)

    # Буфер обмена
    clipped = False
    if not args.no_clipboard:
        clipped = try_copy_to_clipboard(result)

    msg = []
    if clipped:
        msg.append("✅ Текст **скопирован в буфер обмена**.")
    else:
        msg.append("ℹ️ Не удалось скопировать в буфер (нет подходящей утилиты или слишком большой объём).")
    msg.append(f"💾 Результат сохранён в файл: {out_path}")
    msg.append(f"📦 Всего файлов: {len(selected)}")
    print("\n".join(msg))

if __name__ == "__main__":
    main()

