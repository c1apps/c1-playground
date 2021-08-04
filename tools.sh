#!/bin/bash
set -o errexit

OS="$(uname)"

# essential packages
if [ "${OS}" == 'Linux' ]; then
  printf '%s\n' "installing essential packages on linux"
  sudo apt update && \
    sudo apt install -y jq apt-transport-https gnupg2 curl nginx
fi

# brew
if [ "${OS}" == 'Darwin' ]; then
  if ! command -v brew &>/dev/null; then
    printf '%s\n' "installing brew on darwin"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    printf '%s\n' "brew already installed"
    brew update
    brew upgrade
  fi
fi

# docker
if ! command -v docker &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf '%s\n' "installing docker on linux"
    curl -fsSL https://get.docker.com -o get-docker.sh && \
      sudo sh get-docker.sh && \
      ME=$(whoami) && \
      sudo usermod -aG docker ${ME}
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf '%s\n' "installing docker on darwin"
    brew cask install docker
  fi
else
    printf '%s\n' "docker already installed"
fi

# kubectl
if ! command -v kubectl &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf '%s\n' "installing kubectl on linux"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
      echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list && \
      sudo apt-get update && \
      sudo apt-get install -y kubectl
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf '%s\n' "installing kubectl on darwin"
    brew install kubernetes-cli
  fi
else
  printf '%s\n' "kubectl already installed"
fi

# kustomize
if ! command -v kustomize &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf '%s\n' "installing kustomize on linux"
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
      sudo mv ~/kustomize /usr/local/bin
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf '%s\n' "installing kustomize on darwin"
    brew install kustomize
  fi
else
  printf '%s\n' "kustomize already installed"
fi

# helm
if ! command -v helm &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf '%s\n' "installing helm on linux"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
      chmod 700 get_helm.sh && \
      ./get_helm.sh
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf '%s\n' "installing helm on darwin"
    brew install helm
  fi
else
  printf '%s\n' "helm already installed"
fi

# kind
if ! command -v kind &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf '%s\n' "installing kind on linux"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64 && \
      chmod +x ./kind && \
      sudo mv kind /usr/local/bin/
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf '%s\n' "installing kind on darwin"
    brew install kind
  fi
else
  printf '%s\n' "kind already installed"
fi

# krew
if ! command -v ~/.krew/bin/kubectl-krew &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf '%s\n' "installing krew on linux"
    curl -fsSL "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" -o ./krew.tar.gz && \
      tar zxvf ./krew.tar.gz && \
      KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/')" && \
      "$KREW" install krew && \
      rm -f ./krew.tar.gz ./krew-* && \
      echo 'export PATH=~/.krew/bin:$PATH' >> ~/.bashrc
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf '%s\n' "installing krew on darwin"
    brew install krew
    echo 'export PATH="${PATH}:${HOME}/.krew/bin"' >> ~/.zshrc
  fi
else
  printf '%s\n' "krew already installed"
fi

# kubebox
if ! command -v kubebox &>/dev/null; then
  if [ "${OS}" == 'Linux' ]; then
    printf '%s\n' "installing kubebox on linux"
    curl -Lo kubebox https://github.com/astefanutti/kubebox/releases/download/v0.9.0/kubebox-linux && \
      chmod +x kubebox && \
      sudo mv kubebox /usr/local/bin/kubebox
  fi
  if [ "${OS}" == 'Darwin' ]; then
    printf '%s\n' "installing kubebox on darwin"
    curl -Lo kubebox https://github.com/astefanutti/kubebox/releases/download/v0.9.0/kubebox-macos && \
      chmod +x kubebox && \
      sudo mv kubebox /usr/local/bin/kubebox
  fi
else
  printf '%s\n' "kubebox already installed"
fi
