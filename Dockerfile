#
# Known issue:
# # `sudo` does not work when built or run with devmapper
# # CTRL-Z fails. Results in crashing the container when putting emacs in background
#
# To be run with `docker run -i -t -privileged`
#
FROM		stackbrew/ubuntu:13.10
MAINTAINER	Guillaume J. Charmes <guillaume@charmes.net>

RUN		apt-get update

## System
# Install common tools
RUN		apt-get install -y build-essential unzip

# Install SCMs
RUN		apt-get install -y git mercurial

# Install shell
RUN		apt-get install -y zsh zsh-common
#RUN		apt-get install -y fish

# Install editor
RUN		apt-get install -y emacs24
#RUN		apt-get install -y vim

# Install term multiplexer
RUN	        apt-get install -y tmux
#RUN		apt-get install -y screen

# Install a ssh server, just in case
RUN	    	apt-get install -y openssh-server

# Install extra tools
RUN	  	apt-get install -y htop ngrep tcpdump iotop most strace

# Mark user as trusted for mercurial (required for golang install)
RUN		sudo sh -c 'echo "[trusted]\nusers = root" > /etc/mercurial/hgrc'

# Install docker deps
RUN	  	apt-get install -y iptables lxc
RUN		apt-get install -y libsqlite3-dev btrfs-tools aufs-tools
RUN		git clone --no-checkout https://git.fedorahosted.org/git/lvm2.git /usr/local/lvm2 && cd /usr/local/lvm2 && git checkout -q v2_02_103
RUN		cd /usr/local/lvm2 && ./configure --enable-static_link && make device-mapper && make install_device-mapper

## Userland
# set the workdir to home
WORKDIR		/root
ENV		HOME	 /root

# Checkout local configuration files
RUN	   	git clone https://github.com/creack/dotfiles ~/.dotfiles
RUN		cd ~/.dotfiles && make

# Import the gpg private key if not empty
ADD		private.gpg	$HOME/private.gpg
RUN		[ -s $HOME/private.gpg ] || gpg --import - < ~/private.gpg && rm ~/private.gpg

# Download and install Golang
RUN		hg clone https://code.google.com/p/go ~/goroot
RUN		cd ~/goroot/src && ./all.bash

# Setup the golang ENV variables
ENV	    	GOPATH		$HOME/go
ENV		GOROOT		$HOME/goroot
ENV		GOBIN		$GOROOT/bin
ENV		PATH		$GOBIN:$PATH

# Install godef for symbol/tags lookup
RUN	  	go get code.google.com/p/rog-go/exp/cmd/godef
# Install gocode completion
RUN	  	go get github.com/nsf/gocode
# Install goflymake
RUN		go get github.com/dougm/goflymake
# Install gocov
RUN		go get github.com/axw/gocov/gocov

# Checkout docker sources
RUN	   	go get -d github.com/dotcloud/docker
RUN		ln -s ~/go/src/github.com/dotcloud/docker ~/docker

# Set the GOPATH to target docker's vendor
ENV		GOPATH		$HOME/docker/vendor:$GOPATH

# Compile and install docker
RUN		cd docker && ./hack/make.sh binary && cp ./bundles/*/binary/docker-*-dev ~/goroot/bin/docker

CMD		tmux new-session zsh
