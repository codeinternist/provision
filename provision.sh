#!/bin/bash


### process opts ###
if [[ -n "$1" ]]; then
    while [[ -n "$1" ]]; do
        case $1 in
            -b | --basic )          basic=true ;;
            -d | --dev )            dev=true ;;
            -g | --game )           game=true ;;
            -G | --game-icons )     game_icons=true ;;
            -M | --media-icons )    media_icons=true ;;
            -s | --settings)        settings=true ;;
            * )                     echo "usage: provision.sh [-b|--basic] [-d|--dev] [-g|--game] [-s|--settings]"
                                    exit 1
        esac
        shift
    done
else
    basic=true
    dev=true
    game=true
    settings=true
fi


### progress bar ###

# Constants
CODE_SAVE_CURSOR="\033[s"
CODE_RESTORE_CURSOR="\033[u"
CODE_CURSOR_IN_SCROLL_AREA="\033[1A"
COLOR_FG="\e[30m"
COLOR_BG="\e[42m"
COLOR_BG_BLOCKED="\e[43m"
RESTORE_FG="\e[39m"
RESTORE_BG="\e[49m"

# Variables
PROGRESS_BLOCKED="false"
TRAPPING_ENABLED="false"
TRAP_SET="false"

CURRENT_NR_LINES=0

setup_scroll_area() {
    # If trapping is enabled, we will want to activate it whenever we setup the scroll area and remove it when we break the scroll area
    trap_on_interrupt

    lines=$(tput lines)
    CURRENT_NR_LINES=$lines
    let lines=$lines-1
    # Scroll down a bit to avoid visual glitch when the screen area shrinks by one row
    echo -en "\n"

    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"
    # Set scroll region (this will place the cursor in the top left)
    echo -en "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echo -en "$CODE_RESTORE_CURSOR"
    echo -en "$CODE_CURSOR_IN_SCROLL_AREA"

    # Start empty progress bar
    draw_progress_bar 0
}

destroy_scroll_area() {
    lines=$(tput lines)
    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"
    # Set scroll region (this will place the cursor in the top left)
    echo -en "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echo -en "$CODE_RESTORE_CURSOR"
    echo -en "$CODE_CURSOR_IN_SCROLL_AREA"

    # We are done so clear the scroll bar
    clear_progress_bar

    # Scroll down a bit to avoid visual glitch when the screen area grows by one row
    echo -en "\n\n"

    # Once the scroll area is cleared, we want to remove any trap previously set. Otherwise, ctrl+c will exit our shell
    if [ "$TRAP_SET" = "true" ]; then
        trap - INT
    fi
}

draw_progress_bar() {
    percentage=$1
    lines=$(tput lines)
    let lines=$lines

    # Check if the window has been resized. If so, reset the scroll area
    if [ "$lines" -ne "$CURRENT_NR_LINES" ]; then
        setup_scroll_area
    fi

    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # Clear progress bar
    tput el

    # Draw progress bar
    PROGRESS_BLOCKED="false"
    print_bar_text $percentage

    # Restore cursor position
    echo -en "$CODE_RESTORE_CURSOR"
}

block_progress_bar() {
    percentage=$1
    lines=$(tput lines)
    let lines=$lines
    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # Clear progress bar
    tput el

    # Draw progress bar
    PROGRESS_BLOCKED="true"
    print_bar_text $percentage

    # Restore cursor position
    echo -en "$CODE_RESTORE_CURSOR"
}

clear_progress_bar() {
    lines=$(tput lines)
    let lines=$lines
    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # clear progress bar
    tput el

    # Restore cursor position
    echo -en "$CODE_RESTORE_CURSOR"
}

print_bar_text() {
    local percentage=$1
    local cols=$(tput cols)
    let bar_size=$cols-17

    local color="${COLOR_FG}${COLOR_BG}"
    if [ "$PROGRESS_BLOCKED" = "true" ]; then
        color="${COLOR_FG}${COLOR_BG_BLOCKED}"
    fi

    # Prepare progress bar
    let complete_size=($bar_size*$percentage)/100
    let remainder_size=$bar_size-$complete_size
    progress_bar=$(echo -ne "["; echo -en "${color}"; printf_new "#" $complete_size; echo -en "${RESTORE_FG}${RESTORE_BG}"; printf_new "." $remainder_size; echo -ne "]");

    # Print progress bar
    echo -ne " Progress ${percentage}% ${progress_bar}"
}

enable_trapping() {
    TRAPPING_ENABLED="true"
}

trap_on_interrupt() {
    # If this function is called, we setup an interrupt handler to cleanup the progress bar
    TRAP_SET="true"
    trap cleanup_on_interrupt INT
}

cleanup_on_interrupt() {
    destroy_scroll_area
    exit
}

printf_new() {
    str=$1
    num=$2
    v=$(printf "%-${num}s" "$str")
    echo -ne "${v// /$str}"
}

### icon factories ###

desktop_icon() {
    file=$HOME/Desktop/$1.desktop
    touch $file
    echo -e " \
[Desktop Entry]\n \
Encoding=UTF-8\n \
Name=$1\n \
Exec=$3 %U\n \
Icon=$4\n \
Terminal=false\n \
Type=Application\n \
Categories=$2;
" > $file
}

menu_icon() {
    file=$HOME/.local/share/applications/$1.desktop
    touch $file
    echo -e " \
[Desktop Entry]\n \
Encoding=UTF-8\n \
Name=$1\n \
Exec=$3 %U\n \
Icon=$4\n \
Terminal=false\n \
Type=Application\n \
Categories=$2;
" > $file
}

#####################################################
###################     start     ###################
#####################################################

setup_scroll_area

### update apt ###
# sudo apt-get update
echo "change me"
sleep 0.4
draw_progress_bar 2

# sudo apt-get -y upgrade
echo "change me"
sleep 0.4
draw_progress_bar 4


######################
### apply settings ###
######################

if [[ -n "$settings" ]]; then
    echo -e "\n====== Applying Settings ======\n"

    # add bash helpers
    echo -e " \
#!/bin/bash\n \
\n \
# bash aliases\n \
alias ..=\"cd ..\"\n \
alias lsa=\"ls -al\"\n \
alias psx=\"ps auxf\"\n \
alias psu=\"ps -fjH -u \$USER\"\n \
\n \
# bash functions\n \
cdr() { cd \$HOME/source/\$1; }\n \
context() { [[ -n \$1 ]] && export \$(grep -v '^#' \$1 | xargs); }\n \
detach() { [[ -n \$1 ]] && \$@ &>/dev/null & }\n \
mkcd() { mkdir -p \$1; cd \$1; }\n \
rerc() { source ~/.bashrc; source ~/.bash_aliases; source ~/.bash_exports; }\n \
weather() { zip=80204; [[ -n \$1 ]] && zip=\$1; curl https://wttr.in/\$zip; }\n \
" >> $HOME/.bash_aliases
    draw_progress_bar 6

    # install firacode font
    sudo apt-add-repository universe
    sudo apt-get update
    sudo apt-get install fonts-firacode
    draw_progress_bar 8

    # agnoster prompt
    # TODO  install
    draw_progress_bar 10

    # black background
    # TODO  install
    # mint-y-dark
    # TODO  install
fi
draw_progress_bar 12


###############################
### install dev environment ###
###############################

if [[ -n "$dev" ]]; then
    echo -e "\n====== Installing Developer Tools ======\n"

    # setup
    mkdir -p $HOME/source
    echo -e "\n \
# docker aliases\n \
alias dcd=\"docker-compose down\"\n \
alias dclf=\"docker-compose logs --follow\"\n \
alias dcb=\"docker-compose up --build\"\n \
alias dcbd=\"docker-compose up --build -d\"\n \
alias dcu=\"docker-compose up\"\n \
alias dcud=\"docker-compose up -d\"\n \
alias dils=\"docker image ls -a\"\n \
alias dni=\"docker network inspect\"\n \
alias dnls=\"docker network ls\"\n \
alias dps=\"docker ps -a\"\n \
\n \
# docker functions\n \
dnuke() { docker kill \$(docker ps -aq); docker rm \$(docker ps -aq); docker rmi \$(docker image ls -q); }\n \
dup() { tag=\$(tr -dc a-z0-9 </dev/urandom | head -c 10); docker build -t \$tag .; docker run -e LOG_LEVEL=\"debug\" -p 50051:50051 \$tag; }\n \
dupe() { tag=\$(tr -dc a-z0-9 </dev/urandom | head -c 10); docker build -t \$tag .; docker run -e LOG_LEVEL=\"debug\" -e \$(array_join \" -e \" \"\$@\") -p 50051:50051 \$tag; }\n \
dxi() { [[ -n \$1 ]] && docker exec -it \$1 bash; }\n \
logs() { [[ -n \$1 ]] && { id=\$(docker ps -a | grep \"\$1\" | sed 's/ .*//'); [[ -n \$id ]] && docker container logs \$id; }; }\n \
\n \
# git aliases\n \
alias ga=\"\$1\"\n \
alias ga.=\"\$1\"\n \
alias gb=\"\$1\"\n \
alias gca=\"\$1\"\n \
alias gcd=\"\$1\"\n \
alias gd=\"\$1\"\n \
alias gdh=\"\$1\"\n \
alias gf=\"\$1\"\n \
alias gl=\"\$1\"\n \
alias gp=\"\$1\"\n \
alias gpsf=\"\$1\"\n \
alias gr=\"\$1\"\n \
alias grs=\"\$1\"\n \
alias grw=\"\$1\"\n \
alias gs=\"\$1\"\n \
alias gsa=\"\$1\"\n \
alias gsd=\"\$1\"\n \
alias gsl=\"\$1\"\n \
alias gsp=\"\$1\"\n \
alias gss=\"\$1\"\n \
alias gst=\"\$1\"\n \
alias tags=\"\$1\"\n \
\n \
# git functions\n \
gcm() { [[ -n \"\$1\" ]] && { msg=\"\$@\"; git commit -m \"\$(git_branch): \$msg\"; }; }\n \
generic() { git checkout -b generic; git push --set-upstream origin generic; git checkout -; git branch -d generic; }\n \
git_branch() { git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'; }\n \
gpcm() { [[ -n \"\$1\" ]] && { msg=\"\$(git_branch): \$@\"; black .; ga.; git commit -m \"\$msg\"; gps; }; }\n \
gps() {\n \
    git push\n \
    branch=\$(git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
    if [[ \"\$branch\" == \"main\" ]] || [[ \"\$branch\" == \"master\" ]]; then\n \
        git checkout -b generic\n \
        git push --set-upstream origin generic\n \
        git checkout \$branch\n \
        git branch -d generic\n \
    fi\n \
}\n \
gpsu() { git push --set-upstream origin \$(git_branch); }\n \
tag() {\n \
    if [[ -n \"\$1\" ]]; then\n \
        dd=\$(date +\"%Y.%m.%d\")\n \
        ver=\"v/\$dd\"\n \
        msg=\"\$@\"\n \
        ct=\$(git tag -l | grep \"\$ver\" | wc -l)\n \
        [[ \"\$ct\" -ne \"0\" ]] && ver=\"\$ver-\$ct\"\n \
        git tag -a \"\$ver\" -m \"\$msg\"\n \
        git push origin \"\$ver\"\n \
    fi\n \
}\n \
wip() { msg=\"\$(git_branch): [WIP]\"; [[ -n \$1 ]] && msg=\"\$msg  \$@\"; git commit -m \"\$msg\"; }\n \
\n \
# google cloud aliases\n \
alias g=\"gcloud\"\n \
\n \
# helm aliases\n \
alias h=\"helm\"\n \
\n \
# helm completion\n \
. <(helm completion bash)\n \
complete -F __start_helm h\n \
\n \
# kubectl aliases\n \
alias k=\"kubectl\"\n \
alias kaf=\"kubectl apply -f\"\n \
alias kdn=\"kubectl describe nodes\"\n \
alias kdp=\"kubectl describe pods\"\n \
alias kgns=\"kubectl get namespaces\"\n \
alias kx=\"kubectl exec\"\n \
\n \
# kubectl completion\n \
. <(kubectl completion bash)\n \
complete -F __start_kubectl k\n \
\n \
# kubectl functions\n \
kcns() { ns=\$GENERIC_NAMESPACE; [[ -n \"\$1\" ]] && ns=\$1; kubectl config set-context \$(kubectl config current-context) --namespace=\$ns; }\n \
kgp() { msg=\"\"; [[ -n \"\$1\" ]] && msg=\" --field-selector=spec.nodeName=[\$1]\"; kubectl get pods\$msg; }\n \
kgpw() { msg=\"\"; [[ -n \"\$1\" ]] && msg=\" --field-selector=spec.nodeName=[\$1]\"; kubectl get pods\$msg -o wide; }\n \
kxec() { [[ -n \"\$2\" ]] && kubectl exec \$1 -- \$@; }\n \
kxit() { cmd=/bin/sh; [[ -n \"\$2\" ]] && cmd=\"\$@\"; [[ -n \"\$1\" ]] && kubectl exec -it \$1 -- \$cmd; }
\n \
# python functions\n \
dvenv() { deactivate; rm -rf venv; }\n \
venv() { python3 -m venv venv; source venv/bin/activate; pip3 install -r requirements.txt; [[ -f requirements-dev.txt ]] && pip3 install -r requirements-dev.txt; }\n \
\n \
# terraform aliases\n \
alias t=\"terraform\"\n \
alias tfa=\"terraform apply\"\n \
alias tfaf=\"terraform apply -auto-approve\"\n \
alias tfd=\"terraform destroy\"\n \
alias tfdf=\"terraform destroy -auto-approve\"\n \
alias tfi=\"terraform init\"\n \
alias tfo=\"terraform output -json\"\n \
alias tfp=\"terraform plan\"\n \
alias tfs=\"terraform show\"\n \
" >> $HOME/.bash_aliases
    draw_progress_bar 14

    # install deps
    sudo apt-get install -y \
        apt-transport-https \
        build-essential \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget
    draw_progress_bar 16

    # install vs code
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    sudo apt-get update
    sudo apt-get install -y code
    code --install-extension bierner.markdown-mermaid
    code --install-extension coenraads.bracket-pair-colorizer-2
    code --install-extension eamodio.gitlens
    code --install-extension mhutchie.git-graph
    code --install-extension oderwat.indent-rainbow
    code --install-extension redhat.vscode-yaml
    code --install-extension tomoyukim.vscode-mermaid-editor
    draw_progress_bar 18
    
    # install arduino
    mkdir -p $HOME/source/arduino
    wget https://downloads.arduino.cc/arduino-1.8.13-linux64.tar.xz -O /tmp/arduino.tar.xz
    mkdir -p /etc/arduino
    sudo tar xzf /tmp/arduino.tar.xz -C /etc/arduino
    /etc/arduino/install.sh
    draw_progress_bar 20
    
    # install aws-cli
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip /tmp/awscliv2.zip
    sudo /tmp/aws/install
    # TODO  initialize
    draw_progress_bar 22

    # install docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
\$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo groupadd docker
    sudo useradd -aG docker $USER
    code --install-extension ms-azuretools.vscode-docker
    draw_progress_bar 24
    
    # install docker-compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    draw_progress_bar 26

    # install dotnet
    mkdir -p $HOME/source/dotnet
    wget "https://packages.microsoft.com/config/ubuntu/\$(lsb_release -rs)/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
    sudo dpkg -i /tmp/packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y dotnet-sdk-5.0 nuget
    code --install-extension ms-dotnettools.csharp
    draw_progress_bar 28

    # install g++
    sudo apt-get install -y g++
    draw_progress_bar 30

    # install gcloud
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install -y google-cloud-sdk
    # TODO  initialize
    draw_progress_bar 32

    # install git
    sudo apt-get install -y git
    # TODO  initialize
    draw_progress_bar 34

    # install golang
    mkdir -p $HOME/source/go
    mkdir -p $HOME/go/bin
    mkdir -p $HOME/go/src
    wget "https://golang.org/dl/go1.16.3.linux-amd64.tar.gz" -O /tmp/go1.16.3.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf /tmp/go1.16.3.linux-amd64.tar.gz
    export GOPATH=$HOME/go
    export GOBIN=$HOME/go/bin
    export PATH=$PATH:/usr/local/go/bin:$GOBIN
    echo -e " \
export GOPATH=\$HOME/go\n \
export GOBIN=\$HOME/go/bin\n \
export PATH=\$PATH:/usr/local/go/bin:\$GOBIN\n \
" >> $HOME/.bash_exports
    code --install-extension golang.go
    draw_progress_bar 36

    # install helm
    curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
    sudo apt-get install -y apt-transport-https --yes
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install -y helm
    # TODO  initialize
    draw_progress_bar 38

    # install jq
    sudo apt-get install -y jq
    draw_progress_bar 40

    # install kubectl
    gcloud components install kubectl
    # TODO  initialize
    draw_progress_bar 42

    # install latex
    sudo apt-get install -y texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra
    code --install-extension James-Yu.latex-workshop
    draw_progress_bar 44

    # install nodejs
    mkdir -p $HOME/source/nodejs
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
    VERSION=node_8.x
    DISTRO="\$(lsb_release -s -c)"
    echo "deb https://deb.nodesource.com/\$VERSION \$DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    echo "deb-src https://deb.nodesource.com/\$VERSION \$DISTRO main" | sudo tee -a /etc/apt/sources.list.d/nodesource.list
    sudo apt-get update
    sudo apt-get install -y nodejs npm
    echo -e "\n \
# nodejs settings\n \
export NODE_OPTIONS=\"--experimental-repl-await\"\n \
" >> $HOME/.bash_exports
    draw_progress_bar 46

    # install postman
    wget "https://dl-agent.pstmn.io/download/latest/linux" -O /tmp/postman.tar.gz
    sudo tar -C /opt -xzf /tmp/postman.tar.gz
    touch $HOME/.local/share/applications/Postman.desktop
    echo -e " \
[Desktop Entry]\n \
Encoding=UTF-8\n \
Name=Postman\n \
Exec=/opt/Postman/app/Postman %U\n \
Icon=/opt/Postman/app/resources/app/assets/icon.png\n \
Terminal=false\n \
Type=Application\n \
Categories=Development;
" > $HOME/.local/share/applications/Postman.desktop
    draw_progress_bar 48

    # install python
    mkdir -p $HOME/source/python
    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt-get update
    sudo apt-get install -y python3.9
    python3.9 -m pip
    pip install aiohttp black codecov fastapi flake8 pytest pytest-asyncio pytest-cov pytest-timeout requests
    code --install-extension ms-python.python
    draw_progress_bar 50
    
    # install rpi-imager
    sudo apt-get install -y rpi-imager
    draw_progress_bar 52

    # install slack
    sudo apt-get install -y slack-desktop
    # TODO  configuration
    draw_progress_bar 54

    # install terraform
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com \$(lsb_release -cs) main"
    sudo apt-get update
    sudo apt-get install -y terraform
    draw_progress_bar 56

    # install tldr
    npm i -g tldr
    draw_progress_bar 58

    # install yq
    sudo wget https://github.com/mikefarah/yq/releases/download/v4.2.0/yq_linux_amd64 -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
fi
draw_progress_bar 60


##########################
### install basic apps ###
##########################

if [[ -n "$basic" ]]; then
    echo -e "\n====== Installing General Apps ======\n"

    # install draw.io (github.com/jgraph/drawio-desktop)
    wget "https://github.com/jgraph/drawio-desktop/releases/download/v14.5.1/drawio-amd64-14.5.1.deb" -O /tmp/drawio.deb
    sudo gdebi /tmp/drawio.deb
    draw_progress_bar 62

    # install filezilla
    sudo apt-get install -y filezilla
    draw_progress_bar 64

    # install firefox
    sudo apt-get install -y firefox
    draw_progress_bar 65
    #   install ublock origin extension
    wget "https://addons.mozilla.org/firefox/downloads/file/3763753/ublock_origin-1.35.0-an+fx.xpi" -O /tmp/ublock_origin-1.35.0-an+fx.xpi
    firefox /tmp/ublock_origin-1.35.0-an+fx.xpi
    #   install 1password extension
    wget "https://addons.mozilla.org/firefox/downloads/file/3761012/1password_password_manager-1.24.1-fx.xpi" -O /tmp/1password_password_manager-1.24.1-fx.xpi
    firefox /tmp/1password_password_manager-1.24.1-fx.xpi
    #   install darkreader extension
    wget "https://addons.mozilla.org/firefox/downloads/file/3763728/dark_reader-4.9.32-an+fx.xpi" -O /tmp/dark_reader-4.9.32-an+fx.xpi
    firefox /tmp/dark_reader-4.9.32-an+fx.xpi
    draw_progress_bar 66

    # install google chrome
    sudo apt-get install -y google-chrome-stable
    draw_progress_bar 67

    google-chrome-stable --load-extension
    #   install darkreader extension
    sudo touch /opt/google/chrome/extensions/eimadpbcbfnmbkopoojfekhnkhdbieeh.json
    sudo chmod +r /opt/google/chrome/extensions/eimadpbcbfnmbkopoojfekhnkhdbieeh.json
    sudo echo -e " \
{\n \
    \"external_update_url\": \"https://clients2.google.com/service/update2/crx\"\n \
}\n \
" > /opt/google/chrome/extensions/eimadpbcbfnmbkopoojfekhnkhdbieeh.json
    #   install 1password extension
    sudo touch /opt/google/chrome/extensions/aeblfdkhhhdcdjpifhhbdiojplfjncoa.json
    sudo chmod +r /opt/google/chrome/extensions/aeblfdkhhhdcdjpifhhbdiojplfjncoa.json
    sudo echo -e " \
{\n \
    \"external_update_url\": \"https://clients2.google.com/service/update2/crx\"\n \
}\n \
" > /opt/google/chrome/extensions/aeblfdkhhhdcdjpifhhbdiojplfjncoa.json
    #   install ublock origin extension
    sudo touch /opt/google/chrome/extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm.json
    sudo chmod +r /opt/google/chrome/extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm.json
    sudo echo -e " \
{\n \
    \"external_update_url\": \"https://clients2.google.com/service/update2/crx\"\n \
}\n \
" > /opt/google/chrome/extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm.json
    draw_progress_bar 68

    # install google earth
    sudo apt-get install -y google-earth-pro-stable
    draw_progress_bar 70

    # install keybase
    wget "https://prerelease.keybase.io/keybase_amd64.deb" -O /tmp/keybase_amd64.deb
    sudo gdebi /tmp/keybase_amd64.deb
    draw_progress_bar 72

    # install vlc
    sudo apt-get install -y vlc
    draw_progress_bar 74

    # install xpad
    sudo apt-get install -y xpad
fi
draw_progress_bar 76


###########################
### install gaming apps ###
###########################

if [[ -n "$game" ]] || [[ -n "$game_icons" ]]; then
    echo -e "\n====== Installing Gaming Apps ======\n"

    # setup
    sudo dpkg --add-architecture i386
    # TODO  controller drivers

    # install discord
    wget "https://dl.discordapp.net/discord-0.0.14.deb" -O /tmp/discord.deb
    sudo gdebi /tmp/discord.deb
    draw_progress_bar 78

    # install dolphin
    sudo apt-add-repository ppa:dolphin-emu/ppa
    sudo apt update
    sudo apt install -y dolphin-emu
    # TODO  configure
    draw_progress_bar 80

    # install fusion
    sudo apt-get update
    wget "https://www.carpeludum.com/download/kega-fusion_3.63-2_i386.deb" -O /tmp/kega-fusion.deb
    sudo gdebi /tmp/kega-fusion.deb
    # TODO  configure
    draw_progress_bar 82

    # install mupen64plus
    sudo apt-get install -y mupen64plus-qt
    # TODO  configure
    draw_progress_bar 84

    # install nestopia
    sudo apt-get install -y nestopia
    # TODO  configure
    draw_progress_bar 86

    # install pcsx-reloaded
    sudo apt-get install pcsxr
    wget "https://the-eye.eu/public/rom/Bios/psx/scph1001.zip" -O /tmp/scph1001.zip
    # TODO  load bios
    # TODO  configure
    draw_progress_bar 88

    # install pcsx2
    sudo add-apt-repository ppa:gregory-hainaut/pcsx2.official.ppa
    sudo apt update
    sudo apt install -y pcsx2
    wget "https://the-eye.eu/public/rom/Bios/ps2/sony_ps2_%28SCPH39001%29.rar" -O /tmp/scph39001.rar
    # TODO  load bios
    # TODO  configure
    draw_progress_bar 90

    # install redream
    wget "https://redream.io/redream.x86_64-linux-v1.5.0.tar.gz" -O /tmp/redream.tar.gz
    # TODO  install
    # TODO  configure
    draw_progress_bar 92

    # install snes9x
    wget "https://sites.google.com/site/bearoso/snes9x/snes9x_1.60-1_amd64.deb" -O /tmp/snes9x.deb
    sudo gdebi /tmp/snes9x.deb
    # TODO  configure
    draw_progress_bar 94

    # install steam
    wget "https://repo.steampowered.com/steam_latest.deb" -O /tmp/steam.deb
    sudo gdebi /tmp/steam.deb
fi
draw_progress_bar 96


####################################
### install gaming desktop icons ###
####################################

if [[ -n "$game_icons" ]]; then
    echo -e "\n====== Installing Gaming Icons ======\n"
    # discord       Discord
    # TODO  download/store image
    # TODO  create desktop icon
    # dolphin-emu   GameCube + Wii
    # TODO  download/store image
    # TODO  create desktop icon
    # kega-fusion   Sega Genesis
    # TODO  download/store image
    # TODO  create desktop icon
    # mupen64plus   N64
    # TODO  download/store image
    # TODO  create desktop icon
    # nestopia      Nintendo
    # TODO  download/store image
    # TODO  create desktop icon
    # pcsx2         Playstation
    # TODO  download/store image
    # TODO  create desktop icon
    # redream       Dreamcast
    # TODO  download/store image
    # TODO  create desktop icon
    # snes9x        Super Nintendo
    # TODO  download/store image
    # TODO  create desktop icon
    # steam         Steam
    # TODO  download/store image
    # TODO  create desktop icon
fi
draw_progress_bar 98


###################################
### install media desktop icons ###
###################################

if [[ -n "$media_icons" ]]; then
    echo -e "\n====== Installing Media Icons ======\n"
    # Amazon
    # TODO  download/store image
    # TODO  create desktop icon
    # Discovery+
    # TODO  download/store image
    # TODO  create desktop icon
    # ESPN
    # TODO  download/store image
    # TODO  create desktop icon
    # HBO Max
    # TODO  download/store image
    # TODO  create desktop icon
    # Netflix
    # TODO  download/store image
    # TODO  create desktop icon
    # Peacock
    # TODO  download/store image
    # TODO  create desktop icon
    # SportSurge
    # TODO  download/store image
    # TODO  create desktop icon
    # Spotify
    # TODO  download/store image
    # TODO  create desktop icon
    # VLC
    # TODO  download/store image
    # TODO  create desktop icon
    # VoloKit
    # TODO  download/store image
    # TODO  create desktop icon
    # YouTube
    # TODO  download/store image
    # TODO  create desktop icon
fi
draw_progress_bar 100
destroy_scroll_area
