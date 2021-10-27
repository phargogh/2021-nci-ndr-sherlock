import os

try:
    WORKSPACE = os.environ['WORKSPACE_DIR']
except KeyError:
    WORKSPACE = "default/workspace"
print(WORKSPACE)
