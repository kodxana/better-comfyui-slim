#!/bin/bash
set -e

COMFYUI_DIR="/app/ComfyUI"
VENV_DIR="$COMFYUI_DIR/.venv"
DB_FILE="/workspace/filebrowser.db"
ARGS_FILE="/workspace/comfyui_args.txt"

# ---------------------------------------------------------------------------- #
#                          Function Definitions                                  #
# ---------------------------------------------------------------------------- #

setup_ssh() {
    mkdir -p ~/.ssh

    for type in rsa dsa ecdsa ed25519; do
        if [ ! -f "/etc/ssh/ssh_host_${type}_key" ]; then
            ssh-keygen -t ${type} -f "/etc/ssh/ssh_host_${type}_key" -q -N ''
        fi
    done

    if [[ $PUBLIC_KEY ]]; then
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
    else
        RANDOM_PASS=$(openssl rand -base64 12)
        echo "root:${RANDOM_PASS}" | chpasswd
        echo "=========================================="
        echo "SSH Password: ${RANDOM_PASS}"
        echo "=========================================="
    fi

    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config
    /usr/sbin/sshd
}

export_env_vars() {
    printenv | grep -E '^RUNPOD_|^PATH=|^_=|^CUDA|^LD_LIBRARY_PATH|^PYTHONPATH' | while read -r line; do
        echo "export $line" >> /etc/rp_environment
    done
    echo 'source /etc/rp_environment' >> ~/.bashrc
}

start_filebrowser() {
    if [ ! -f "$DB_FILE" ]; then
        filebrowser config init
        filebrowser config set --address 0.0.0.0
        filebrowser config set --port 8080
        filebrowser config set --root /workspace
        filebrowser config set --auth.method=noauth
        filebrowser users add admin admin --perm.admin
    fi
    echo "Starting FileBrowser on port 8080..."
    nohup filebrowser --database "$DB_FILE" &> /var/log/filebrowser.log &
}

start_zasper() {
    echo "Starting Zasper on port 8048..."
    nohup zasper --port 0.0.0.0:8048 --cwd /workspace &> /var/log/zasper.log &
}

setup_workspace_links() {
    # Create workspace directories for user data
    mkdir -p /workspace/models
    mkdir -p /workspace/output
    mkdir -p /workspace/input
    mkdir -p /workspace/custom_nodes

    # Link workspace directories into ComfyUI
    if [ ! -L "$COMFYUI_DIR/models" ]; then
        rm -rf "$COMFYUI_DIR/models"
        ln -sf /workspace/models "$COMFYUI_DIR/models"
    fi

    if [ ! -L "$COMFYUI_DIR/output" ]; then
        rm -rf "$COMFYUI_DIR/output"
        ln -sf /workspace/output "$COMFYUI_DIR/output"
    fi

    if [ ! -L "$COMFYUI_DIR/input" ]; then
        rm -rf "$COMFYUI_DIR/input"
        ln -sf /workspace/input "$COMFYUI_DIR/input"
    fi

    # User custom nodes: merge workspace custom_nodes into the baked-in ones
    if [ -d "/workspace/custom_nodes" ]; then
        for node_dir in /workspace/custom_nodes/*/; do
            if [ -d "$node_dir" ]; then
                node_name=$(basename "$node_dir")
                if [ ! -e "$COMFYUI_DIR/custom_nodes/$node_name" ]; then
                    ln -sf "$node_dir" "$COMFYUI_DIR/custom_nodes/$node_name"
                    echo "Linked user custom node: $node_name"
                fi
            fi
        done
    fi
}

update_comfyui() {
    if [ "${UPDATE_COMFYUI:-false}" = "true" ]; then
        echo "Updating ComfyUI..."
        cd "$COMFYUI_DIR"
        git pull --ff-only || echo "ComfyUI update failed, using baked-in version"

        echo "Updating custom nodes..."
        cd "$COMFYUI_DIR/custom_nodes"
        for node_dir in */; do
            if [ -d "$node_dir/.git" ]; then
                echo "Updating $node_dir..."
                (cd "$node_dir" && git pull --ff-only) || echo "Failed to update $node_dir"
            fi
        done
    fi
}

# ---------------------------------------------------------------------------- #
#                               Main Program                                     #
# ---------------------------------------------------------------------------- #

echo "============================================"
echo "  Better ComfyUI - RTX 5090 (CUDA 12.8)"
echo "============================================"

# Runtime setup
setup_ssh
export_env_vars
start_filebrowser
start_zasper

# Workspace symlinks (models, outputs, inputs persist on volume)
setup_workspace_links

# Optional: update ComfyUI if env var is set
update_comfyui

# Activate venv
source "$VENV_DIR/bin/activate"

# Install deps for any user-added custom nodes from workspace
if [ -d "/workspace/custom_nodes" ]; then
    for node_dir in /workspace/custom_nodes/*/; do
        if [ -d "$node_dir" ] && [ -f "${node_dir}requirements.txt" ]; then
            echo "Installing deps for user node: $(basename $node_dir)"
            uv pip install -r "${node_dir}requirements.txt" || true
        fi
    done
fi

# Create default args file if it doesn't exist
if [ ! -f "$ARGS_FILE" ]; then
    echo "# Add custom ComfyUI arguments here (one per line)" > "$ARGS_FILE"
    echo "# Example: --highvram" >> "$ARGS_FILE"
    echo "# Example: --preview-method auto" >> "$ARGS_FILE"
fi

# Build ComfyUI launch command
cd "$COMFYUI_DIR"
FIXED_ARGS="--listen 0.0.0.0 --port 8188"
CUSTOM_ARGS=""

if [ -s "$ARGS_FILE" ]; then
    CUSTOM_ARGS=$(grep -v '^#' "$ARGS_FILE" | grep -v '^$' | tr '\n' ' ')
fi

echo "Starting ComfyUI..."
echo "  Args: $FIXED_ARGS $CUSTOM_ARGS"
exec python main.py $FIXED_ARGS $CUSTOM_ARGS
