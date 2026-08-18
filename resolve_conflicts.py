#!/usr/bin/env python3
import sys

def resolve_conflict(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    lines = content.split('\n')
    result = []
    in_conflict = False
    side = None  # 'head' or 'theirs'
    head_lines = []
    theirs_lines = []
    
    for line in lines:
        if line.startswith('<<<<<<< HEAD'):
            in_conflict = True
            side = 'head'
            continue
        elif line.startswith('=======') and in_conflict:
            side = 'theirs'
            continue
        elif line.startswith('>>>>>>> ') and in_conflict:
            in_conflict = False
            # Merge: keep both sides' additions
            result.extend(head_lines)
            result.extend(theirs_lines)
            head_lines = []
            theirs_lines = []
            continue
        
        if in_conflict:
            if side == 'head':
                head_lines.append(line)
            else:
                theirs_lines.append(line)
        else:
            result.append(line)
    
    with open(filepath, 'w') as f:
        f.write('\n'.join(result))
    print(f"Resolved: {filepath}")

if __name__ == '__main__':
    for fp in sys.argv[1:]:
        resolve_conflict(fp)
