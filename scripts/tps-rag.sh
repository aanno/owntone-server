#!/usr/bin/env bash
# Run this script in devcontainer. But before, run this _outside_ devcontainer:
#
# cd gaeko-backend
# git clone --recursive git@github.com:aanno/cocoindex-code-mcp-server.git
# cd cocoindex-code-mcp-server
# cp .env.template .env
# ./scripts/cocoindex-postgresql.sh

# perhaps in .bashrc
export JAVA_HOME=/usr/lib/jvm/msopenjdk-current
# end of perhaps in .bashrc

if [ -z "$PODMAN" ]; then
    PODMAN=$(which podman || which docker)
fi
echo "Using PODMAN=$PODMAN"

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel)

pushd "$GIT_ROOT"

set -a
source podman/env.podman.local
set +a

sudo apt update
sudo apt full-upgrade -y
sudo apt install -y python3 python-is-python3 cargo rustc
# https://docs.astral.sh/uv/getting-started/installation/
# installs to /home/vscode/.local/bin/uv
curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv
. .venv/bin/activate

pushd "cocoindex-code-mcp-server"

uv self update

uv pip install -e .
uv pip install -e ".[test]"
uv pip install -e ".[build]"
uv pip install -e ".[act]"
uv lock

maturin dev
uv pip install -e ".[mcp-server,test]"
# needed?
. .env
# problem here (tp): wants postgresql on localhost
./scripts/install-pgvector.py || true
# uv run python -m cocoindex_code_mcp_server.main_mcp_server --rescan --port 3033 /workspaces/java
uv run python -m cocoindex_code_mcp_server.main_mcp_server --host 0.0.0.0 --port 3033 --exclude '**/*.xml' \
  --exclude '**/*.html' --exclude '**/*.js' --exclude '**/*.ts' --exclude '**/*.log*'\
  --exclude 'dataport_deployment/**' --exclude 'libs/**' --exclude 'repo/**' --exclude 'report/**' \
  --exclude '**/target/**' --exclude '.venv/**' \
  --exclude '**/cocoindex/**' --exclude '**/astchunk/**' --exclude '**/ai-enhanced-app-dev/**' \
  --exclude '**/code-index-mcp/**' --exclude '**/tests_broken/**' \
  /workspaces/java

# really needed?
# stores to /home/tpasch/.cache/huggingface/hub/models--sentence-transformers--all-mpnet-base-v2
hf download sentence-transformers/all-mpnet-base-v2

curl -fsSL https://claude.ai/install.sh | bash

# old memory
# claude mcp add --transport sse gw-memory http://host.docker.internal:3012/sse
# new memory - https://github.com/doobidoo/mcp-memory-service
claude mcp add --transport http memory http://host.docker.internal:8765/mcp
# only vs code
# claude mcp add --transport http vscode-mcp-server http://localhost:30033
# problem here:
# cococoindex should be run within container
# claude mcp add --transport http cocoindex-rag http://host.docker.internal:3033/mcp
claude mcp add --transport http cocoindex-rag http://localhost:3033/mcp
claude mcp add-json fetch '{
      "command": "uvx",
      "args": [
        "mcp-server-fetch"
      ]
    }'
claude mcp add git '{
      "command": "uvx",
      "args": [
        "mcp-server-git"
      ]
    }'

popd

popd

# always need after starting a new terminal/console
# . ~/.bashrc; . .venv/bin/activate
# . ~/.bashrc; . .venv/bin/activate; export PATH=~/.local/bin:$PATH
