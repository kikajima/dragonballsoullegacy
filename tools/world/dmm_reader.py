"""Minimal BYOND .dmm parser (TGM and classic formats)."""
import re
from collections import Counter

ATOM_RE = re.compile(r'(/[\w/]+)(\{.*?\})?(?=,/|$)', re.S)
VAR_RE = re.compile(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|\'[^\']*\'|[^;]+)')


def parse_atoms(body):
    atoms = []
    for m in ATOM_RE.finditer(body.strip()):
        path, varblock = m.group(1), m.group(2)
        vars_ = {}
        if varblock:
            for vm in VAR_RE.finditer(varblock[1:-1]):
                v = vm.group(2).strip()
                if v[:1] in '"\'':
                    v = v[1:-1]
                vars_[vm.group(1)] = v
        atoms.append((path, vars_))
    return atoms


def load(path):
    text = open(path, encoding='latin-1').read()
    keys = {}
    i = 0
    key_re = re.compile(r'"(\w+)" = \(')
    grid_start = text.find('\n(1,1,')
    if grid_start < 0:
        grid_start = text.find('(1,1,')
    head = text[:grid_start]
    pos = 0
    while True:
        m = key_re.search(head, pos)
        if not m:
            break
        # find matching close paren at depth 0, skipping strings
        j = m.end()
        depth = 1
        in_str = None
        while depth:
            c = head[j]
            if in_str:
                if c == '\\':
                    j += 1
                elif c == in_str:
                    in_str = None
            elif c in '"\'':
                in_str = c
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            j += 1
        keys[m.group(1)] = parse_atoms(head[m.end():j - 1])
        pos = j
    keylen = len(next(iter(keys)))
    zs = {}
    for gm in re.finditer(r'\((\d+),(\d+),(\d+)\) = \{"\n?(.*?)\n?"\}', text[grid_start:], re.S):
        x0, y0, z = int(gm.group(1)), int(gm.group(2)), int(gm.group(3))
        rows = [r for r in gm.group(4).split('\n') if r]
        grid = [[r[k:k + keylen] for k in range(0, len(r), keylen)] for r in rows]
        zs.setdefault(z, []).append((x0, y0, grid))
    return keys, zs
