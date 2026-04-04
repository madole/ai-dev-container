#\!/bin/bash
set -euo pipefail

GIT_DELTA_VERSION="${GITDELTAVERSION:-0.18.2}"
ZSH_IN_DOCKER_VERSION="1.2.0"

# Install dev tool packages
apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  nano \
  vim \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install git-delta
ARCH=$(dpkg --print-architecture)
wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up zsh with powerlevel10k for the remote user
su - "${_REMOTE_USER}" -c "sh -c \"\$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)\" -- \
  -p git \
  -p fzf \
  -a \"source /usr/share/doc/fzf/examples/key-bindings.zsh\" \
  -a \"source /usr/share/doc/fzf/examples/completion.zsh\" \
  -x"

# Set zsh as default shell for the remote user
chsh -s /bin/zsh "${_REMOTE_USER}"

echo "Dev tools installed."
