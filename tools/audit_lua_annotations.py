"""List likely annotation gaps; heuristics guide review and do not infer contracts."""

import argparse
from collections import Counter
from dataclasses import dataclass
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
GLOBAL_NAMES = frozenset(('assert', 'collectgarbage', 'debug', 'error', 'getmetatable', 'ipairs',
                          'loadfile', 'math', 'next', 'package', 'pairs', 'pcall', 'rawequal',
                          'rawget', 'rawset', 'require', 'select', 'setmetatable', 'string', 'table',
                          'tonumber', 'tostring', 'type', 'unpack', 'xpcall'))


@dataclass(frozen=True)
class Token:
    value: str
    start: int
    end: int
    line: int
    kind: str = 'symbol'


def tokens(source):
    """Lex Lua strings/comments as units so comment text cannot masquerade as code."""
    result = []
    cursor = 0
    line = 1
    while cursor < len(source):
        start, first_line = cursor, line
        char = source[cursor]
        kind = 'symbol'
        if char.isspace():
            cursor += 1
            if char == '\n':
                line += 1
            continue
        comment = source.startswith('--', cursor)
        if comment:
            cursor += 2
        long_open = re.match(r'\[(=*)\[', source[cursor:])
        if long_open:
            closing = ']' + long_open.group(1) + ']'
            end = source.find(closing, cursor + long_open.end())
            if end == -1:
                raise ValueError(f'unclosed long string/comment at line {first_line}')
            cursor = end + len(closing)
            kind = 'comment' if comment else 'string'
        elif comment:
            end = source.find('\n', cursor)
            cursor = len(source) if end == -1 else end
            kind = 'comment'
        elif char in ('"', "'"):
            cursor += 1
            while cursor < len(source):
                if source[cursor] == '\\':
                    cursor += 2
                elif source[cursor] == char:
                    cursor += 1
                    break
                else:
                    cursor += 1
            else:
                raise ValueError(f'unclosed string at line {first_line}')
            kind = 'string'
        else:
            match = re.match(r'[A-Za-z_][A-Za-z_0-9]*|(?:0[xX][0-9A-Fa-f]+(?:\.[0-9A-Fa-f]*)?(?:[pP][+-]?\d+)?|\d+(?:\.(?!\.)\d*)?(?:[eE][+-]?\d+)?)(?:[uUlLiI]+)?|\.\.\.|\.\.|==|~=|<=|>=|::|//|<<|>>', source[cursor:])
            cursor += len(match.group(0)) if match else 1
            kind = 'name' if re.match(r'[A-Za-z_]', char) else 'symbol'
        value = source[start:cursor]
        line += value.count('\n')
        if kind != 'comment':
            result.append(Token(value, start, cursor, first_line, kind))
    return result


def functions(source):
    code = tokens(source)
    result = []
    for index, token in enumerate(code):
        if token.value != 'function':
            continue
        opening = index + 1
        while opening < len(code) and code[opening].value != '(':
            opening += 1
        if opening == len(code):
            continue
        closing = opening + 1
        while closing < len(code) and code[closing].value != ')':
            closing += 1
        name = ''.join(item.value for item in code[index + 1:opening])
        params = [item.value for item in code[opening + 1:closing] if item.value != ',']
        line_start = source.rfind('\n', 0, token.start) + 1
        lines = source[:line_start].splitlines()
        doc_lines = []
        doc_line = token.line - 1
        for previous in reversed(lines):
            if previous.strip().startswith('--'):
                doc_lines.insert(0, previous)
                doc_line -= 1
            else:
                break
        docs = '\n'.join(doc_lines)
        annotated = re.findall(r'---@param\s+([\w.]+)\??\s', docs)
        stack = ['function']
        waiting = set()
        ending = closing + 1
        own_returns = []
        for position in range(closing + 1, len(code)):
            value = code[position].value
            if code[position].kind == 'string':
                continue
            if value in ('function', 'if', 'for', 'while', 'repeat'):
                stack.append(value)
                if value in ('for', 'while'):
                    waiting.add(len(stack))
            elif value == 'do':
                if len(stack) in waiting:
                    waiting.remove(len(stack))
                else:
                    stack.append('do')
            elif value in ('end', 'until'):
                stack.pop()
                if not stack:
                    ending = position
                    break
            elif value == 'return' and stack.count('function') == 1:
                following = code[position + 1]
                if following.value not in ('end', 'else', 'elseif', 'until', ';'):
                    own_returns.append(following.value)
        result.append({'name': name or '<callback>', 'line': token.line,
                       'params': params, 'documented_params': annotated,
                       'missing_params': [param for param in params if param not in annotated and param != 'self'],
                       'has_return': bool(re.search(r'---\s*@return(?:\s|_)', docs)),
                       'docs': docs, 'start': token.start, 'params_end': code[closing].end,
                       'end': code[ending].end, 'returns': own_returns,
                       'body': source[code[closing].end:code[ending].start]})
    return result


def class_contracts(sources):
    classes = {}
    for source in sources:
        for match in re.finditer(r'---@class\s+([\w.]+)(?:<[^\n]*?>)?(?:\s*:\s*([^\n]+))?\n((?:---[^\n]*\n)*)', source):
            name, parents, docs = match.groups()
            classes[name.split('.')[-1]] = {
                'fields': set(re.findall(r'---@field\s+(?:(?:private|protected|public)\s+)?([\w]+)\??', docs)),
                'parents': [name.strip().split('.')[-1] for name in (parents or '').split(',')],
            }
    return classes


def inherited_fields(name, classes, seen=None):
    seen = set() if seen is None else seen
    if name in seen or name not in classes:
        return set()
    seen.add(name)
    fields = set(classes[name]['fields'])
    for parent in classes[name]['parents']:
        fields.update(inherited_fields(parent, classes, seen))
    return fields


def scan(path, source, classes=None):
    findings = []
    code = tokens(source)
    locals_ = set(re.findall(r'\blocal\s+(\w+)\s*=', source))
    params = {param for function in functions(source) for param in function['params']}
    seen_globals = set()
    for index, token in enumerate(code):
        if token.value not in GLOBAL_NAMES or token.value in locals_ or token.value in params:
            continue
        previous = code[index - 1].value if index else ''
        following = code[index + 1].value if index + 1 < len(code) else ''
        if previous in ('.', ':') or following == '=' or token.value in ('require', 'package', 'loadfile'):
            continue  # Module loading is intentionally kept dynamic.
        if token.value not in seen_globals:
            findings.append({'line': token.line, 'kind': 'global-review', 'name': token.value,
                             'detail': 'possible unlocalized global read; confirm scope before editing'})
            seen_globals.add(token.value)
    for function in functions(source):
        if function['name'] == '<callback>':
            continue  # Most inline callbacks inherit their containing field/call signature.
        if function['missing_params']:
            findings.append({'line': function['line'], 'kind': 'parameter', 'name': function['name'],
                             'detail': ', '.join(function['missing_params'])})
        if classes and ':' in function['name']:
            owner = function['name'].split(':')[0]
            known = inherited_fields(owner, classes)
            if owner in classes:
                for field in sorted(set(re.findall(r'\bself\.(\w+)\s*=(?!=)', function['body'])) - known):
                    findings.append({'line': function['line'], 'kind': 'field-review',
                                     'name': owner + '.' + field,
                                     'detail': 'assignment without a known own/inherited field; check structural or generic contract'})
        forwards_canvas = function['name'].startswith('PaintingContext:') and 'return self.canvas:' in function['body']
        if not function['has_return'] and function['returns'] and not function['name'].endswith('__init') and not forwards_canvas:
            findings.append({'line': function['line'], 'kind': 'return-review', 'name': function['name'],
                             'detail': 'check return contract or exact inherited signature'})
    declarations = re.findall(r'---@class\s+([^\s:]+)[^\n]*\n((?:---[^\n]*\n)*)\s*local\s+(\w+)\s*=\s*(?:std\.class\.new|dataclass\.new)', source)
    for declared, docs, local_name in declarations:
        if '---@overload' not in docs:
            start = source.find('local ' + local_name + ' =')
            findings.append({'line': source[:start].count('\n') + 1, 'kind': 'constructor',
                             'name': declared, 'detail': 'missing constructor overload'})
    return findings


def source_files(paths):
    result = set()
    for value in paths:
        path = (ROOT / value).resolve()
        if not path.is_relative_to(ROOT) or not path.exists():
            raise ValueError(f'invalid repository path: {value}')
        result.update([path] if path.is_file() else path.rglob('*.lua'))
    return sorted(path for path in result if path.suffix == '.lua'
                  and path.relative_to(ROOT).as_posix() != 'lib/fonts/fluent_icon_names.lua')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='*', default=['player', 'lib'])
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--compare-ref', help='compare executable tokens with a Git ref; never executes Lua')
    parser.add_argument('--allow-local-aliases', action='store_true',
                        help='when comparing, remove local name = name declarations from both revisions')
    parser.add_argument('--fields', action='store_true', help='include approximate instance-field coverage')
    args = parser.parse_args(argv)
    try:
        files = source_files(args.paths or ['player', 'lib'])
        reports = []
        differences = []
        contracts = class_contracts(path.read_text(encoding='utf-8-sig') for path in source_files(['player', 'lib'])) if args.fields else None
        for path in files:
            relative = path.relative_to(ROOT).as_posix()
            source = path.read_text(encoding='utf-8-sig')
            reports.append({'file': relative, 'findings': scan(path, source, contracts)})
            if args.compare_ref:
                previous = subprocess.run(['git', 'show', f'{args.compare_ref}:{relative}'], cwd=ROOT,
                                          capture_output=True, text=True, encoding='utf-8', check=True).stdout
                if args.allow_local_aliases:
                    previous = re.sub(r'^local (\w+) = \1\s*$', '', previous, flags=re.M)
                    source = re.sub(r'^local (\w+) = \1\s*$', '', source, flags=re.M)
                left = [item.value for item in tokens(previous)]
                right = [item.value for item in tokens(source)]
                if left != right:
                    differences.append(relative)
        counts = Counter(item['kind'] for report in reports for item in report['findings'])
        output = {'files': reports, 'summary': {'file_count': len(files), 'findings': dict(counts)},
                  'token_differences': differences if args.compare_ref else None,
                  'limits': 'heuristic; inherited methods, inferred callbacks and generic/structural fields need manual review; not full type coverage'}
        if args.json:
            print(json.dumps(output, ensure_ascii=False, indent=2))
        else:
            for report in reports:
                for finding in report['findings']:
                    print(f"{report['file']}:{finding['line']} [{finding['kind']}] {finding['name']}: {finding['detail']}")
            print(json.dumps(output['summary'], ensure_ascii=False))
            if args.compare_ref:
                print('Executable token differences: ' + (', '.join(differences) or 'none'))
        return 1 if differences else 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
