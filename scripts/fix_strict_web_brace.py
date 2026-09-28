from pathlib import Path

p = Path('SarahIA/SarahIA/Services/MultiAgentCoordinator.swift')
s = p.read_text()
old = '''            }
        }
        }
    }
    
    // Alias rétrocompatible
'''
new = '''            }
        }
    }
    
    // Alias rétrocompatible
'''
if old not in s:
    raise SystemExit('duplicate coordinator brace target not found')
p.write_text(s.replace(old, new, 1))
print('Removed duplicate MultiAgentCoordinator brace')
