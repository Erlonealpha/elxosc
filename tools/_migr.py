from collections import defaultdict
import re
import subprocess

# 执行检测命令
r = subprocess.run(['emmylua_check', '.'], capture_output=True)
data = r.stdout.decode()

text = 'does not satisfy the constraint `std.object`'
text2 = 'std.class.new'

_iter = iter(data.splitlines())
lines = []

def next_line():
    try:
        line = next(_iter)
        lines.append(line)
        return line
    except StopIteration:
        return None

# 正则表达式
file_patt = re.compile(r'^\s*-->\s*([A-Za-z]:[\\/][^\s:]+):(\d+):(\d+)$')
content_patt = re.compile(r'^\s*(\d+)\s*\|\s*(.+)$')

# 核心：用于解析和替换 std.class.new 参数的正则
# 捕获组 1: 前缀 (如 `local DefaultApp = std.class.new(`)
# 捕获组 2: 类名字符串 (如 `'DefaultApp'` 或 `"DefaultApp"`)
# 捕获组 3: 第二个参数大括号内部的内容 (如 ` StatefulWidget ` 或空)
# 捕获组 4: 后缀 (大括号后面的内容，如 ` )` 或 `)` 等)
class_new_patt = re.compile(r"(.*std\.class\.new\s*\(\s*['\"][\w_]+['\"]\s*,\s*)\{([^}]*)\}(\s*\).*)$")
# 特殊情况：如果原来就没有第二个参数，或者第二个参数不是大括号（防御性跳过）

# 用于存放需要修改的文件和行信息
# 结构: { file_path: { line_num: (old_content, new_content) } }
process_map = defaultdict(dict)

while True:
    line = next_line()
    if line is None:
        break
    if text in line:
        file_line = next_line()
        if file_line is None:
            break
        file = file_patt.match(file_line)
        if file is None:
            print(f'cannot match file {file_line}')
            continue
        
        file_path = file.group(1)
        
        visit_empty = False
        target_line = None
        while True:
            line = next_line()
            if line == '':
                if visit_empty:
                    break
                visit_empty = True
                continue
            if line is None:
                break
            content = content_patt.match(line)
            if content is None:
                break
            if text2 in content.group(2):
                target_line = content
                break
        
        if target_line is not None:
            line_num = int(target_line.group(1))
            old_code = target_line.group(2)
            
            # 尝试匹配并转换 API 用法
            match_class = class_new_patt.search(old_code)
            if match_class:
                prefix = match_class.group(1)
                bases_str = match_class.group(2).strip()
                suffix = match_class.group(3)
                
                # 分析 base 的数量
                if not bases_str:
                    # 情况 1: 空的大括号 {} -> 去掉第二个参数和前面的逗号
                    # 此时 prefix 结尾形如 ",'DefaultApp', "，需要去掉最后的逗号和空格
                    new_prefix = re.sub(r'\s*,\s*$', '', prefix)
                    new_code = f"{new_prefix}{suffix}"
                else:
                    # 情况 2: 存在 base，按逗号切分
                    bases = [b.strip() for b in bases_str.split(',') if b.strip()]
                    if len(bases) == 1:
                        # 只有一个 base -> 成功迁移为单继承平铺
                        new_code = f"{prefix}{bases[0]}{suffix}"
                    else:
                        # 多个 base -> 跳过不做修改
                        continue
                
                # 记录转换结果
                process_map[file_path][line_num] = (old_code, new_code)

# 统一回写文件（按文件维度处理，防止频繁读写）
for file_path, line_updates in process_map.items():
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            file_lines = f.readlines()
        
        modified = False
        for line_num, (old_code, new_code) in line_updates.items():
            # 数组下标从 0 开始，日志行号从 1 开始
            idx = line_num - 1
            if idx < len(file_lines):
                # 检查原有代码片段是否确实包含在文件中，避免错位修改
                if old_code.strip() in file_lines[idx]:
                    # 保持原行的换行符和前导缩进
                    indent = file_lines[idx][:len(file_lines[idx]) - len(file_lines[idx].lstrip())]
                    file_lines[idx] = f"{indent}{new_code.strip()}\n"
                    modified = True
                    print(f"[修改] {file_path}:{line_num}\n  旧: {old_code.strip()}\n  新: {new_code.strip()}")
        
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(file_lines)
                
    except Exception as e:
        print(f"处理文件 {file_path} 时发生错误: {e}")
