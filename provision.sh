#!/bin/bash

### settings ###
# TODO  automate latest versions
DOCKER_COMPOSE_VERSION=1.29.1
GOLANG_VERSION=1.16.3
NODE_VERSION=node_14.x
PYTHON_VERSION=3.10
SLACK_VERSION=4.15.0
YQ_VERSION=v4.2.0
DRAWIO_VERSION=v14.5.1
UBLOCK_ORIGIN_VERSION=1.35.0
ONEPASSWORD_VERSION=1.24.1
DARKREADER_VERSION=4.9.32
MULTI_CONTAINER_VERSION=7.3.0
RELEASE_NAME=focal
RELEASE_VERSION=20.04

### process opts ###
if [[ -n "$1" ]]; then
    while [[ -n "$1" ]]; do
        case $1 in
            -a | --all )            basic=true
                                    dev=true
                                    game_icons=true
                                    media_icons=true
                                    settings=true ;;
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
    # desktop_icon NAME TYPE PATH ICON_URL
    icon="/etc/icons/$1.${4: -3}"
    file=$HOME/Desktop/$1.desktop
    [[ -f $icon ]] || sudo wget $4 -O $icon
    touch $file
    echo -e "\
[Desktop Entry]\n\
Encoding=UTF-8\n\
Name=$1\n\
Exec=$3 %U\n\
Icon=$icon\n\
Terminal=false\n\
Type=Application\n\
Categories=$2;
" > $file
}

desktop_link() {
    # menu_icon [--ff] NAME TYPE URL ICON_URL
    if [[ "$1" == "--ff" ]]; then
        name="$2"
        type="$3"
        exec="firefox $4"
        icon_url="$5"
    else
        name="$1"
        type="$2"
        exec="google-chrome --new-window $3"
        icon_url="$4"
    fi

    icon="/etc/icons/$1.${4: -3}"
    file=$HOME/Desktop/$name.desktop
    [[ -f $icon ]] || sudo wget $icon_url -O $icon
    touch $file
    echo -e "\
[Desktop Entry]\n\
Encoding=UTF-8\n\
Name=$name\n\
Exec=$exec\n\
Icon=$icon\n\
Terminal=false\n\
Type=Application\n\
Categories=$type;
" > $file
}

menu_icon() {
    # menu_icon NAME TYPE PATH ICON
    file=$HOME/.local/share/applications/$1.desktop
    touch $file
    echo -e "\
[Desktop Entry]\n\
Encoding=UTF-8\n\
Name=$1\n\
Exec=$3 %U\n\
Icon=$4\n\
Terminal=false\n\
Type=Application\n\
Categories=$2;
" > $file
}

mydir() {
    id=`id -nu`
    grp=`id -ng`
    sudo mkdir -p $1
    sudo chown $id:$grp $1
}

#####################################################
###################     start     ###################
#####################################################

setup_scroll_area

### add repositories and keys ###
sudo add-apt-repository -y ppa:graphics-drivers/ppa

### update apt ###
echo ">>>  updating apt"
sudo apt-get update
draw_progress_bar 2

echo ">>>  upgrading installed packages"
sudo apt-get -y upgrade
draw_progress_bar 8


######################
### apply settings ###
######################

if [[ -n "$settings" ]]; then
    echo -e "\n====== Applying Settings ======\n"

    cinn() { gsettings set org.cinnamon.$@; }

    # set black background
    echo ">>>  setting cinnamon background"
    cinn desktop.background picture-uri 'file:///usr/share/backgrounds/linuxmint/default_background.jpg'
    cinn desktop.background picture-opacity 100
    cinn desktop.background picture-options 'none'
    cinn desktop.background primary-color '#000000'
    cinn desktop.background secondary-color '#000000'
    cinn desktop.background color-shading-type 'solid'

    # set mint-y-dark
    echo ">>>  setting cinnamon theme"
    cinn desktop.interface icon-theme 'Mint-Y-Dark-Aqua'
    cinn desktop.interface gtk-theme 'Mint-Y-Dark-Aqua'
    cinn theme name 'Mint-Y-Dark-Aqua'
fi
draw_progress_bar 10


###############################
### install dev environment ###
###############################

if [[ -n "$dev" ]]; then
    echo -e "\n====== Installing Developer Tools ======\n"

    # setup
    mkdir -p $HOME/source

    # install firacode font
    echo -e "\n>>> installing firacode font <<<\n"
    sudo apt-add-repository universe
    sudo apt-get update
    sudo apt-get install fonts-firacode
    draw_progress_bar 12

    # configure gnome terminal
    uuid=`gsettings get org.gnome.Terminal.ProfilesList default | sed "s|'||g"`
    prof="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$uuid/"
    gsettings set $prof foreground-color 'rgb(255,255,255)'
    gsettings set $prof background-color 'rgb(0,0,0)'
    gsettings set $prof use-theme-colors false
    gsettings set $prof font "Fira Code Retina 10"
    gsettings set $prof use-system-font false

    # add agnoster prompt
    echo ">>>  writing .bashrc"
    echo -e " \
# ~/.bashrc: executed by bash(1) for non-login shells.\n\
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)\n\
# for examples\n\
\n\
# If not running interactively, don't do anything\n\
case \$- in\n\
    *i*) ;;\n\
      *) return;;\n\
esac\n\
\n\
# don't put duplicate lines or lines starting with space in the history.\n\
# See bash(1) for more options\n\
HISTCONTROL=ignoreboth\n\
\n\
# append to the history file, don't overwrite it\n\
shopt -s histappend\n\
\n\
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)\n\
HISTSIZE=1000\n\
HISTFILESIZE=2000\n\
\n\
# check the window size after each command and, if necessary,\n\
# update the values of LINES and COLUMNS.\n\
shopt -s checkwinsize\n\
\n\
# If set, the pattern \"**\" used in a pathname expansion context will\n\
# match all files and zero or more directories and subdirectories.\n\
#shopt -s globstar\n\
\n\
# make less more friendly for non-text input files, see lesspipe(1)\n\
[ -x /usr/bin/lesspipe ] && eval \"\$(SHELL=/bin/sh lesspipe)\"\n\
\n\
# set variable identifying the chroot you work in (used in the prompt below)\n\
if [ -z \"\${debian_chroot:-}\" ] && [ -r /etc/debian_chroot ]; then\n\
    debian_chroot=\$(cat /etc/debian_chroot)\n\
fi\n\
\n\
PROMPT_DIRTRIM=4\n\
\n\
######################################################################\n\
DEBUG=0\n\
debug() {\n\
    if [[ \${DEBUG} -ne 0 ]]; then\n\
        >&2 echo -e \$*\n\
    fi\n\
}\n\
\n\
######################################################################\n\
### Segment drawing\n\
# A few utility functions to make it easy and re-usable to draw segmented prompts\n\
\n\
CURRENT_BG='NONE'\n\
CURRENT_RBG='NONE'\n\
SEGMENT_SEPARATOR=''\n\
RIGHT_SEPARATOR=''\n\
LEFT_SUBSEG=''\n\
RIGHT_SUBSEG=''\n\
\n\
text_effect() {\n\
    case \"\$1\" in\n\
        reset)      echo 0;;\n\
        bold)       echo 1;;\n\
        underline)  echo 4;;\n\
    esac\n\
}\n\
\n\
# to add colors, see\n\
# http://bitmote.com/index.php?post/2012/11/19/Using-ANSI-Color-Codes-to-Colorize-Your-Bash-Prompt-on-Linux\n\
# under the \"256 (8-bit) Colors\" section, and follow the example for orange below\n\
fg_color() {\n\
    case \"\$1\" in\n\
        black)      echo 38\;5\;0;;\n\
        red)        echo 31;;\n\
        green)      echo 38\;5\;22;;\n\
        yellow)     echo 38\;5\;184;;\n\
        blue)       echo 38\;5\;19;;\n\
        magenta)    echo 35;;\n\
        cyan)       echo 36;;\n\
        white)      echo 38\;5\;15;;\n\
        orange)     echo 38\;5\;166;;\n\
        darkgrey)   echo 38\;5\;236;;\n\
        navy)       echo 38\;5\;19;;\n\
    esac\n\
}\n\
\n\
bg_color() {\n\
    case \"\$1\" in\n\
        black)      echo 48\;5\;0;;\n\
        red)        echo 41;;\n\
        green)      echo 48\;5\;22;;\n\
        yellow)     echo 48\;5\;184;;\n\
        blue)       echo 48\;5\;19;;\n\
        magenta)    echo 45;;\n\
        cyan)       echo 46;;\n\
        white)      echo 48\;5\;15;;\n\
        orange)     echo 48\;5\;166;;\n\
        darkgrey)   echo 48\;5\;236;;\n\
        navy)       echo 48\;5\;19;;\n\
    esac;\n\
}\n\
\n\
ansi() {\n\
    local seq\n\
    declare -a mycodes=(\"\${!1}\")\n\
\n\
    debug \"ansi: \${!1} all: \$* aka \${mycodes[@]}\"\n\
\n\
    seq=\"\"\n\
    for ((i = 0; i < \${#mycodes[@]}; i++)); do\n\
        if [[ -n \$seq ]]; then\n\
            seq=\"\${seq};\"\n\
        fi\n\
        seq=\"\${seq}\${mycodes[\$i]}\"\n\
    done\n\
    debug \"ansi debug:\" '\\[\\033['\${seq}'m\\]'\n\
    echo -ne '\[\033['\${seq}'m\]'\n\
    # PR=\"\$PR\[\033[\${seq}m\]\"\n\
}\n\
\n\
ansi_single() {\n\
    echo -ne '\[\033['\$1'm\]'\n\
}\n\
\n\
# Begin a segment\n\
# Takes two arguments, background and foreground. Both can be omitted,\n\
# rendering default background/foreground.\n\
prompt_segment() {\n\
    local bg fg\n\
    declare -a codes\n\
\n\
    debug \"Prompting \$1 \$2 \$3\"\n\
\n\
    # if commented out from kruton's original... I'm not clear\n\
    # if it did anything, but it messed up things like\n\
    # prompt_status - Erik 1/14/17\n\
\n\
    #    if [[ -z \$1 || ( -z \$2 && \$2 != default ) ]]; then\n\
    codes=(\"\${codes[@]}\" \$(text_effect reset))\n\
    #    fi\n\
    if [[ -n \$1 ]]; then\n\
        bg=\$(bg_color \$1)\n\
        codes=(\"\${codes[@]}\" \$bg)\n\
        debug \"Added \$bg as background to codes\"\n\
    fi\n\
    if [[ -n \$2 ]]; then\n\
        fg=\$(fg_color \$2)\n\
        codes=(\"\${codes[@]}\" \$fg)\n\
        debug \"Added \$fg as foreground to codes\"\n\
    fi\n\
\n\
    debug \"Codes: \"\n\
    # declare -p codes\n\
\n\
    if [[ \$CURRENT_BG != NONE && \$1 != \$CURRENT_BG ]]; then\n\
        declare -a intermediate=(\$(fg_color \$CURRENT_BG) \$(bg_color \$1))\n\
        debug \"pre prompt \" \$(ansi intermediate[@])\n\
        PR=\"\$PR \$(ansi intermediate[@])\$SEGMENT_SEPARATOR\"\n\
        debug \"post prompt \" \$(ansi codes[@])\n\
        PR=\"\$PR\$(ansi codes[@]) \"\n\
    else\n\
        debug \"no current BG, codes is \$codes[@]\"\n\
        PR=\"\$PR\$(ansi codes[@]) \"\n\
    fi\n\
    CURRENT_BG=\$1\n\
    [[ -n \$3 ]] && PR=\"\$PR\$3\"\n\
}\n\
\n\
# End the prompt, closing any open segments\n\
prompt_end() {\n\
    if [[ -n \$CURRENT_BG ]]; then\n\
        declare -a codes=(\$(text_effect reset) \$(fg_color \$CURRENT_BG))\n\
        PR=\"\$PR \$(ansi codes[@])\$SEGMENT_SEPARATOR\"\n\
    fi\n\
    declare -a reset=(\$(text_effect reset))\n\
    PR=\"\$PR \$(ansi reset[@])\"\n\
    CURRENT_BG=''\n\
}\n\
\n\
### virtualenv prompt\n\
prompt_virtualenv() {\n\
    if [[ -n \$VIRTUAL_ENV ]]; then\n\
        color=cyan\n\
        prompt_segment \$color \$PRIMARY_FG\n\
        prompt_segment \$color white \"\$(basename \$VIRTUAL_ENV)\"\n\
    fi\n\
}\n\
\n\
\n\
### Prompt components\n\
# Each component will draw itself, and hide itself if no information needs to be shown\n\
\n\
# Context: user@hostname (who am I and where am I)\n\
prompt_context() {\n\
    local user=`whoami`\n\
\n\
    if [[ \$user != \$DEFAULT_USER || -n \$SSH_CLIENT ]]; then\n\
        prompt_segment darkgrey default \"\$user\"\n\
    fi\n\
}\n\
\n\
# prints history followed by HH:MM, useful for remembering what\n\
# we did previously\n\
prompt_histdt() {\n\
    prompt_segment black default \"\! [\A]\"\n\
}\n\
\n\
\n\
git_status_dirty() {\n\
    dirty=\$(git status -s 2> /dev/null | tail -n 1)\n\
    [[ -n \$dirty ]] && echo \" ●\"\n\
}\n\
\n\
# Git: branch/detached head, dirty status\n\
prompt_git() {\n\
    local ref dirty\n\
    if \$(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then\n\
        ZSH_THEME_GIT_PROMPT_DIRTY='±'\n\
        dirty=\$(git_status_dirty)\n\
        ref=\$(git symbolic-ref HEAD 2> /dev/null) \\\n\
            || ref=\"➦ \$(git describe --exact-match --tags HEAD 2> /dev/null)\" \\\n\
            || ref=\"➦ \$(git show-ref --head -s --abbrev | head -n1 2> /dev/null)\"\n\
        if [[ -n \$dirty ]]; then\n\
            prompt_segment yellow black\n\
        else\n\
            prompt_segment green white\n\
        fi\n\
        PR=\"\$PR\${ref/refs\/heads\// }\$dirty\"\n\
    fi\n\
}\n\
\n\
# Mercurial: clean, modified and uncomitted files\n\
prompt_hg() {\n\
    local rev st branch\n\
    if \$(hg id >/dev/null 2>&1); then\n\
        if \$(hg prompt >/dev/null 2>&1); then\n\
            if [[ \$(hg prompt \"{status|unknown}\") = \"?\" ]]; then\n\
                # if files are not added\n\
                prompt_segment red white\n\
                st='±'\n\
            elif [[ -n \$(hg prompt \"{status|modified}\") ]]; then\n\
                # if any modification\n\
                prompt_segment yellow black\n\
                st='±'\n\
            else\n\
                # if working copy is clean\n\
                prompt_segment green black \$CURRENT_FG\n\
            fi\n\
            PR=\"\$PR\$(hg prompt \"☿ {rev}@{branch}\") \$st\"\n\
        else\n\
            st=\"\"\n\
            rev=\$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')\n\
            branch=\$(hg id -b 2>/dev/null)\n\
            if \`hg st | grep -q \"^\?\"\`; then\n\
                prompt_segment red white\n\
                st='±'\n\
            elif \`hg st | grep -q \"^[MA]\"\`; then\n\
                prompt_segment yellow black\n\
                st='±'\n\
            else\n\
                prompt_segment green black \$CURRENT_FG\n\
            fi\n\
            PR=\"\$PR☿ \$rev@\$branch \$st\"\n\
        fi\n\
    fi\n\
}\n\
\n\
# Dir: current working directory\n\
prompt_dir() {\n\
    prompt_segment blue white '\w'\n\
}\n\
\n\
# Status:\n\
# - was there an error\n\
# - am I root\n\
# - are there background jobs?\n\
prompt_status() {\n\
    local symbols\n\
    symbols=()\n\
    [[ \$RETVAL -ne 0 ]] && symbols+=\"\$(ansi_single \$(fg_color red))✘\"\n\
    [[ \$UID -eq 0 ]] && symbols+=\"\$(ansi_single \$(fg_color yellow))⚡\"\n\
    [[ \$(jobs -l | wc -l) -gt 0 ]] && symbols+=\"\$(ansi_single \$(fg_color cyan))⚙\"\n\
\n\
    [[ -n \"\$symbols\" ]] && prompt_segment black default \"\$symbols\"\n\
}\n\
\n\
build_prompt() {\n\
    [[ ! -z \${AG_EMACS_DIR+x} ]] && prompt_emacsdir\n\
    prompt_status\n\
    #[[ -z \${AG_NO_HIST+x} ]] && prompt_histdt\n\
    [[ -z \${AG_NO_CONTEXT+x} ]] && prompt_context\n\
    prompt_virtualenv\n\
    prompt_dir\n\
    prompt_git\n\
    prompt_hg\n\
    prompt_end\n\
}\n\
\n\
set_bash_prompt() {\n\
    RETVAL=\$?\n\
    PR=\"\"\n\
    PRIGHT=\"\"\n\
    CURRENT_BG=NONE\n\
    PR=\"\$(ansi_single \$(text_effect reset))\"\n\
    build_prompt\n\
\n\
    # uncomment below to use right prompt\n\
    #     PS1='\[\$(tput sc; printf \"%*s\" \$COLUMNS \"\$PRIGHT\"; tput rc)\]'\$PR\n\
    PS1=\$PR\n\
}\n\
\n\
PROMPT_COMMAND=set_bash_prompt\n\
\n\
# some more ls aliases\n\
alias ll='ls -alF'\n\
alias la='ls -A'\n\
alias l='ls -CF'\n\
\n\
# Add an \"alert\" alias for long running commands.  Use like so:\n\
#   sleep 10; alert\n\
alias alert='notify-send --urgency=low -i \"\$([ \$? = 0 ] && echo terminal || echo error)\" \"\$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert\$//'\'')\"'\n\
\n\
# Alias definitions.\n\
# You may want to put all your additions into a separate file like\n\
# ~/.bash_aliases, instead of adding them here directly.\n\
# See /usr/share/doc/bash-doc/examples in the bash-doc package.\n\
\n\
if [ -f ~/.bash_aliases ]; then\n\
    . ~/.bash_aliases\n\
fi\n\
\n\
if [ -f ~/.bash_exports ]; then\n\
    . ~/.bash_exports\n\
fi\n\
\n\
# enable programmable completion features (you don't need to enable\n\
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile\n\
# sources /etc/bash.bashrc).\n\
if ! shopt -oq posix; then\n\
    if [ -f /usr/share/bash-completion/bash_completion ]; then\n\
        . /usr/share/bash-completion/bash_completion\n\
    elif [ -f /etc/bash_completion ]; then\n\
        . /etc/bash_completion\n\
    fi\n\
fi\n\
\
" > $HOME/.bashrc
    echo ">>>  writing .bash_aliases"
    echo -e "\
# bash aliases\n\
alias ..=\"cd ..\"\n\
alias lsa=\"ls -al\"\n\
alias psx=\"ps auxf\"\n\
alias psu=\"ps -fjH -u \$USER\"\n\
\n\
# bash functions\n\
cdr() { cd \$HOME/source/\$1; }\n\
context() { [[ -n \$1 ]] && export \$(grep -v '^#' \$1 | xargs); }\n\
detach() { [[ -n \$1 ]] && \$@ &>/dev/null & }\n\
mkcd() { mkdir -p \$1; cd \$1; }\n\
rerc() { source ~/.bashrc; source ~/.bash_aliases; source ~/.bash_exports; }\n\
weather() { zip=80204; [[ -n \$1 ]] && zip=\$1; curl https://wttr.in/\$zip; }\n\
\n\
# docker aliases\n\
alias dcd=\"docker-compose down\"\n\
alias dclf=\"docker-compose logs --follow\"\n\
alias dcb=\"docker-compose up --build\"\n\
alias dcbd=\"docker-compose up --build -d\"\n\
alias dcu=\"docker-compose up\"\n\
alias dcud=\"docker-compose up -d\"\n\
alias dils=\"docker image ls -a\"\n\
alias dni=\"docker network inspect\"\n\
alias dnls=\"docker network ls\"\n\
alias dps=\"docker ps -a\"\n\
\n\
# docker functions\n\
dnuke() { docker kill \$(docker ps -aq); docker rm \$(docker ps -aq); docker rmi \$(docker image ls -q); }\n\
dup() { tag=\$(tr -dc a-z0-9 </dev/urandom | head -c 10); docker build -t \$tag .; docker run -e LOG_LEVEL=\"debug\" -p 50051:50051 \$tag; }\n\
dupe() { tag=\$(tr -dc a-z0-9 </dev/urandom | head -c 10); docker build -t \$tag .; docker run -e LOG_LEVEL=\"debug\" -e \$(array_join \" -e \" \"\$@\") -p 50051:50051 \$tag; }\n\
dxi() { [[ -n \$1 ]] && docker exec -it \$1 bash; }\n\
logs() { [[ -n \$1 ]] && { id=\$(docker ps -a | grep \"\$1\" | sed 's/ .*//'); [[ -n \$id ]] && docker container logs \$id; }; }\n\
\n\
# git aliases\n\
alias ga=\"git add\"\n\
alias ga.=\"git add .\"\n\
alias gb=\"git branch\"\n\
alias gca=\"git commit --amend --no-edit\"\n\
alias gcd=\"git checkout\"\n\
alias gd=\"git diff\"\n\
alias gdh=\"git diff HEAD\"\n\
alias gf=\"git fetch\"\n\
alias gl=\"git log\"\n\
alias gp=\"git pull\"\n\
alias gpsf=\"git push --force-with-lease\"\n\
alias gr=\"git restore\"\n\
alias grs=\"git restore --staged\"\n\
alias gs=\"git status\"\n\
alias gsa=\"git stash apply\"\n\
alias gsd=\"git stash drop\"\n\
alias gsl=\"git stash list\"\n\
alias gsp=\"git stash pop\"\n\
alias gss=\"git stash show -p\"\n\
alias gst=\"git stash\"\n\
alias tags=\"git tag -l\"\n\
\n\
# git functions\n\
gcm() { [[ -n \"\$1\" ]] && { msg=\"\$@\"; git commit -m \"\$(git_branch): \$msg\"; }; }\n\
generic() { git checkout -b generic; git push --set-upstream origin generic; git checkout -; git branch -d generic; }\n\
git_branch() { git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'; }\n\
gpcm() { [[ -n \"\$1\" ]] && { msg=\"\$(git_branch): \$@\"; black .; ga.; git commit -m \"\$msg\"; gps; }; }\n\
gps() {\n\
    git push\n\
    branch=\$(git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
    if [[ \"\$branch\" == \"main\" ]] || [[ \"\$branch\" == \"master\" ]]; then\n\
        git checkout -b generic\n\
        git push --set-upstream origin generic\n\
        git checkout \$branch\n\
        git branch -d generic\n\
    fi\n\
}\n\
gpsu() { git push --set-upstream origin \$(git_branch); }\n\
grw() { [[ -n \"\$1\" ]] && git reset HEAD~\$1; }\n\
tag() {\n\
    if [[ -n \"\$1\" ]]; then\n\
        dd=\$(date +\"%Y.%m.%d\")\n\
        ver=\"v/\$dd\"\n\
        msg=\"\$@\"\n\
        ct=\$(git tag -l | grep \"\$ver\" | wc -l)\n\
        [[ \"\$ct\" -ne \"0\" ]] && ver=\"\$ver-\$ct\"\n\
        git tag -a \"\$ver\" -m \"\$msg\"\n\
        git push origin \"\$ver\"\n\
    fi\n\
}\n\
wip() { msg=\"\$(git_branch): [WIP]\"; [[ -n \$1 ]] && msg=\"\$msg  \$@\"; git commit -m \"\$msg\"; gps; }\n\
\n\
# google cloud aliases\n\
alias g=\"gcloud\"\n\
\n\
# helm aliases\n\
alias h=\"helm\"\n\
\n\
# helm completion\n\
. <(helm completion bash)\n\
complete -F __start_helm h\n\
\n\
# kubectl aliases\n\
alias k=\"kubectl\"\n\
alias kaf=\"kubectl apply -f\"\n\
alias kdn=\"kubectl describe nodes\"\n\
alias kdp=\"kubectl describe pods\"\n\
alias kgns=\"kubectl get namespaces\"\n\
alias kx=\"kubectl exec\"\n\
\n\
# kubectl completion\n\
. <(kubectl completion bash)\n\
complete -F __start_kubectl k\n\
\n\
# kubectl functions\n\
kcns() { ns=\$GENERIC_NAMESPACE; [[ -n \"\$1\" ]] && ns=\$1; kubectl config set-context \$(kubectl config current-context) --namespace=\$ns; }\n\
kgp() { msg=\"\"; [[ -n \"\$1\" ]] && msg=\" --field-selector=spec.nodeName=[\$1]\"; kubectl get pods\$msg; }\n\
kgpw() { msg=\"\"; [[ -n \"\$1\" ]] && msg=\" --field-selector=spec.nodeName=[\$1]\"; kubectl get pods\$msg -o wide; }\n\
kxec() { [[ -n \"\$2\" ]] && kubectl exec \$1 -- \$@; }\n\
kxit() { cmd=/bin/sh; [[ -n \"\$2\" ]] && cmd=\"\$@\"; [[ -n \"\$1\" ]] && kubectl exec -it \$1 -- \$cmd; }
\n\
# python functions\n\
dvenv() { deactivate; rm -rf venv; }\n\
venv() { python3 -m venv venv; source venv/bin/activate; pip3 install -r requirements.txt; [[ -f requirements-dev.txt ]] && pip3 install -r requirements-dev.txt; }\n\
\n\
# terraform aliases\n\
alias t=\"terraform\"\n\
alias tfa=\"terraform apply\"\n\
alias tfaf=\"terraform apply -auto-approve\"\n\
alias tfd=\"terraform destroy\"\n\
alias tfdf=\"terraform destroy -auto-approve\"\n\
alias tfi=\"terraform init\"\n\
alias tfo=\"terraform output -json\"\n\
alias tfp=\"terraform plan\"\n\
alias tfs=\"terraform show\"\n\
" > $HOME/.bash_aliases
    draw_progress_bar 14

    # install deps
    echo -e "\n>>> installing deps <<<\n"
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

    # install jq
    echo -e "\n>>> installing jq <<<\n"
    sudo apt-get install -y jq
    draw_progress_bar 18

    # install vs code
    echo -e "\n>>> installing vs code <<<\n"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    sudo apt-get update
    sudo apt-get install -y code

    # configure vs code
    code --install-extension bierner.markdown-mermaid
    code --install-extension coenraads.bracket-pair-colorizer-2
    code --install-extension eamodio.gitlens
    code --install-extension mhutchie.git-graph
    code --install-extension oderwat.indent-rainbow
    code --install-extension redhat.vscode-yaml
    code --install-extension tomoyukim.vscode-mermaid-editor

    sets=$HOME/.config/Code/User/settings.json
    jq -n '{"editor.fontFamily":"Fira Code"}' > $sets
    crst() { jq ". |= . + {\"$1\":false}" $sets; }
    cset() { jq ". |= . + {\"$1\":true}" $sets; }
    cstr() { jq ". |= . + {\"$1\":\"$2\"}" $sets; }

    cset editor.fontLigatures
    cstr latex-workshop.view.pdf.viewer tab
    cset extensions.ignoreRecommendations
    cstr arduino.path "/usr/local/bin/arduino"
    crst telemetry.enableCrashReporter
    crst telemetry.enableTelemetry
    crst update.showReleaseNotes
    draw_progress_bar 20
    
    # install arduino
    echo -e "\n>>> installing arduino <<<\n"
    mkdir -p $HOME/source/arduino
    wget https://downloads.arduino.cc/arduino-1.8.13-linux64.tar.xz -O /tmp/arduino.tar.xz
    mydir /etc/arduino
    tar xf /tmp/arduino.tar.xz -C /etc/arduino
    /etc/arduino/install.sh
    sudo ln -s /etc/arduino/arduino-1.8.13/arduino /usr/local/bin/arduino
    draw_progress_bar 22
    
    # install aws-cli   PEND
    echo -e "\n>>> installing aws-cli <<<\n"
    wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O /tmp/awscliv2.zip
    sudo mkdir -p /etc/awscli
    sudo unzip /tmp/awscliv2.zip -d /etc/awscli
    sudo /tmp/aws/install
    sudo ln -s /etc/awscli/aws/dist/aws /usr/local/bin/aws
    draw_progress_bar 24

    # install docker
    echo -e "\n>>> installing docker <<<\n"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
$RELEASE_NAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo groupadd docker
    sudo useradd -aG docker $USER
    code --install-extension ms-azuretools.vscode-docker
    draw_progress_bar 26
    
    # install docker-compose
    echo -e "\n>>> installing docker-compose <<<\n"
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    draw_progress_bar 28

    # install dotnet
    echo -e "\n>>> installing dotnet <<<\n"
    mkdir -p $HOME/source/dotnet
    wget "https://packages.microsoft.com/config/ubuntu/$RELEASE_VERSION/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
    sudo dpkg -i /tmp/packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y dotnet-sdk-5.0 nuget
    code --install-extension ms-dotnettools.csharp
    draw_progress_bar 30

    # install g++
    echo -e "\n>>> installing g++ <<<\n"
    sudo apt-get install -y g++
    draw_progress_bar 32

    # install gcloud
    echo -e "\n>>> installing gcloud <<<\n"
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update
    sudo apt-get install -y google-cloud-sdk
    draw_progress_bar 34

    # install git
    echo -e "\n>>> installing git <<<\n"
    sudo add-apt-repository -y ppa:git-core/ppa
    sudo apt-get update
    sudo apt-get install -y git
    draw_progress_bar 36

    # install golang
    echo -e "\n>>> installing golang <<<\n"
    mkdir -p $HOME/source/go
    mkdir -p $HOME/go/bin
    mkdir -p $HOME/go/src
    wget "https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz" -O /tmp/go$GOLANG_VERSION.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf /tmp/go$GOLANG_VERSION.linux-amd64.tar.gz
    export GOPATH=$HOME/go
    export GOBIN=$HOME/go/bin
    export PATH=$PATH:/usr/local/go/bin:$GOBIN
    echo -e " \
export GOPATH=\$HOME/go\n\
export GOBIN=\$HOME/go/bin\n\
export PATH=\$PATH:/usr/local/go/bin:\$GOBIN\n\
" >> $HOME/.bash_exports
    code --install-extension golang.go
    draw_progress_bar 38

    # install helm
    echo -e "\n>>> installing helm <<<\n"
    curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install -y helm
    draw_progress_bar 40

    # install kubectl
    echo -e "\n>>> installing kubectl <<<\n"
    sudo apt-get install -y kubectl
    draw_progress_bar 42

    # install latex
    echo -e "\n>>> installing latex <<<\n"
    sudo apt-get install -y texlive-latex-base texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra
    code --install-extension James-Yu.latex-workshop
    draw_progress_bar 44

    # install nodejs
    echo -e "\n>>> installing nodejs <<<\n"
    mkdir -p $HOME/source/nodejs
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
    echo "deb https://deb.nodesource.com/$NODE_VERSION $RELEASE_NAME main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    echo "deb-src https://deb.nodesource.com/$NODE_VERSION $RELEASE_NAME main" | sudo tee -a /etc/apt/sources.list.d/nodesource.list
    sudo apt-get update
    sudo apt-get install -y nodejs npm
    echo -e "\n\
# nodejs settings\n\
export NODE_OPTIONS=\"--experimental-repl-await\"\n\
" >> $HOME/.bash_exports
    draw_progress_bar 46

    # install postman   TODO    configure (no sign in; dark mode)
    echo -e "\n>>> installing postman <<<\n"
    wget "https://dl.pstmn.io/download/latest/linux64" -O /tmp/postman.tar.gz
    mydir /opt/postman
    tar -C /opt/postman -xzf /tmp/postman.tar.gz
    menu_icon Postman Development /opt/postman/Postman/app/Postman /opt/postman/Postman/app/resources/app/assets/icon.png
    draw_progress_bar 48

    # install python
    echo -e "\n>>> installing python $PYTHON_VERSION <<<\n"
    mkdir -p $HOME/source/python
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update
    sudo apt-get install -y python$PYTHON_VERSION
    python$PYTHON_VERSION -m pip
    pip install aiohttp black codecov fastapi flake8 pytest pytest-asyncio pytest-cov pytest-timeout requests
    code --install-extension ms-python.python
    draw_progress_bar 50
    
    # install rpi-imager
    echo -e "\n>>> installing raspberry pi imager <<<\n"
    wget "https://downloads.raspberrypi.org/imager/imager_latest_amd64.deb" -O /tmp/rpi-imager.deb
    sudo gdebi -n /tmp/rpi-imager.deb
    draw_progress_bar 52

    # install slack     TODO configure (dark mode)
    echo -e "\n>>> installing slack <<<\n"
    wget "https://downloads.slack-edge.com/linux_releases/slack-desktop-$SLACK_VERSION-amd64.deb" -O /tmp/slack.deb
    sudo gdebi -n /tmp/slack.deb
    draw_progress_bar 54

    # install terraform
    echo -e "\n>>> installing terraform <<<\n"
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $RELEASE_NAME main"
    sudo apt-get update
    sudo apt-get install -y terraform
    draw_progress_bar 56

    # install tldr
    echo -e "\n>>> installing tldr <<<\n"
    sudo apt-get install -y tldr
    draw_progress_bar 58

    # TODO  install typescript

    # install yq
    echo -e "\n>>> installing yq <<<\n"
    sudo wget https://github.com/mikefarah/yq/releases/download/$YQ_VERSION/yq_linux_amd64 -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
fi
draw_progress_bar 60


##########################
### install basic apps ###
##########################

if [[ -n "$basic" ]]; then
    echo -e "\n====== Installing General Apps ======\n"

    # install draw.io    TODO    configure (dark mode)
    echo -e "\n>>> installing draw.io <<<\n"
    wget "https://github.com/jgraph/drawio-desktop/releases/download/$DRAWIO_VERSION/drawio-amd64-14.5.1.deb" -O /tmp/drawio.deb
    sudo gdebi -n /tmp/drawio.deb
    draw_progress_bar 62

    # install filezilla
    echo -e "\n>>> installing filezilla <<<\n"
    sudo apt-get install -y filezilla
    draw_progress_bar 64

    # install firefox
    echo -e "\n>>> installing firefox <<<\n"
    sudo apt-get install -y firefox
    draw_progress_bar 65

    #   install ublock origin extension
    echo -e "\n>>> installing ublock origin extension <<<\n"
    wget "https://addons.mozilla.org/firefox/downloads/file/3763753/ublock_origin-$UBLOCK_ORIGIN_VERSION-an+fx.xpi" -O /tmp/ublock_origin-$UBLOCK_ORIGIN_VERSION-an+fx.xpi
    firefox /tmp/ublock_origin-$UBLOCK_ORIGIN_VERSION-an+fx.xpi
    #   install 1password extension
    echo -e "\n>>> installing 1password extension <<<\n"
    wget "https://addons.mozilla.org/firefox/downloads/file/3761012/1password_password_manager-$ONEPASSWORD_VERSION-fx.xpi" -O /tmp/1password_password_manager-$ONEPASSWORD_VERSION-fx.xpi
    firefox /tmp/1password_password_manager-$ONEPASSWORD_VERSION-fx.xpi
    #   install darkreader extension
    echo -e "\n>>> installing darkreader extension <<<\n"
    wget "https://addons.mozilla.org/firefox/downloads/file/3763728/dark_reader-$DARKREADER_VERSION-an+fx.xpi" -O /tmp/dark_reader-$DARKREADER_VERSION-an+fx.xpi
    firefox /tmp/dark_reader-$DARKREADER_VERSION-an+fx.xpi
    #   install multi-container extension
    echo -e "\n>>> installing multi-container extension <<<\n"
    wget "https://addons.mozilla.org/firefox/downloads/file/3713375/firefox_multi_account_containers-$MULTI_CONTAINER_VERSION-fx.xpi" -O /tmp/firefox_multi_account_containers-$MULTI_CONTAINER_VERSION-fx-xpi
    firefox /tmp/firefox_multi_account_containers-$MULTI_CONTAINER_VERSION-fx.xpi

    #   configure firefox   FIXME
    echo ">>>  configuring firefox preferences"
    ff_dir="$HOME/.mozilla/firefox"
    user_dir=`ls $ff_dir | grep default$`
    ff_prefs="$ff_dir/$user_dir/prefs.js"
    touch $ff_prefs
    echo "user_pref('app.normandy.enabled', false);" >> $ff_prefs
    echo "user_pref('browser.search.region', 'US');" >> $ff_prefs
    echo "user_pref('browser.startup.homepage', 'about:blank');" >> $ff_prefs
    echo "user_pref('browser.urlbar.placeholderName', 'DuckDuckGo');" >> $ff_prefs
    echo "user_pref('browser.urlbar.placeholderName.private', 'DuckDuckGo');" >> $ff_prefs
    echo "user_pref('browser.newtabpage.activity-stream.feeds.section.highlights', false);" >> $ff_prefs
    echo "user_pref('browser.newtabpage.activity-stream.feeds.section.topstories', false);" >> $ff_prefs
    echo "user_pref('browser.newtabpage.activity-stream.showSearch', false);" >> $ff_prefs
    echo "user_pref('browser.newtabpage.activity-stream.showSponsored', false);" >> $ff_prefs
    echo "user_pref('browser.newtabpage.activity-stream.showSponsoredTopSites', false);" >> $ff_prefs
    echo "user_pref('browser.newtabpage.activity-stream.topSitesRows', 4);" >> $ff_prefs
    echo "user_pref('browser.urlbar.trimURLs', false);" >> $ff_prefs
    echo "user_pref('extensions.activeThemeID', 'firefox-compact-dark@mozilla.org');" >> $ff_prefs
    echo "user_pref('general.smoothScroll', false);" >> $ff_prefs
    echo "user_pref('general.smoothScroll.mouseWheel.migrationPercent', 0);" >> $ff_prefs
    echo "user_pref('media.autoplay.default', 5);" >> $ff_prefs
    echo "user_pref('network.dns.disablePrefetch', true);" >> $ff_prefs
    echo "user_pref('network.http.speculative-parallel-limit', 0);" >> $ff_prefs
    echo "user_pref('network.predictor.cleaned-up', true);" >> $ff_prefs
    echo "user_pref('network.predictor.enabled', false);" >> $ff_prefs
    echo "user_pref('network.prefetch-next', false);" >> $ff_prefs
    echo "user_pref('permissions.default.camera', 2);" >> $ff_prefs
    echo "user_pref('permissions.default.desktop-notification', 2);" >> $ff_prefs
    echo "user_pref('permissions.default.geo', 2);" >> $ff_prefs
    echo "user_pref('privacy.popups.policy', 1);" >> $ff_prefs
    draw_progress_bar 66

    # install google chrome
    echo -e "\n>>> installing google chrome <<<\n"
    wget "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -O /tmp/chrome.deb
    sudo gdebi -n /tmp/chrome.deb
    draw_progress_bar 67

    mydir /opt/google/chrome/extensions
    chrext() { 
        sudo touch /opt/google/chrome/extensions/$1.json
        sudo chmod +r /opt/google/chrome/extensions/$1.json
        sudo echo -e '{"external_update_url":"https://clients2.google.com/service/update2/crx"}' > $1.json
    }
    #   install darkreader extension    FIXME
    echo -e "\n>>> installing darkreader extension <<<\n"
    chrext eimadpbcbfnmbkopoojfekhnkhdbieeh
    #   install 1password extension     FIXME
    echo -e "\n>>> installing 1password extension <<<\n"
    chrext aeblfdkhhhdcdjpifhhbdiojplfjncoa
    #   install ublock origin extension FIXME
    echo -e "\n>>> installing ublock origin extension <<<\n"
    chrext cjpalhdlnbpafiamejdnhcphjbkeiagm
    draw_progress_bar 68

    # install google earth
    echo -e "\n>>> installing google earth <<<\n"
    sudo apt-get install -y google-earth-pro-stable
    draw_progress_bar 70

    # install keybase
    echo -e "\n>>> installing keybase <<<\n"
    wget "https://prerelease.keybase.io/keybase_amd64.deb" -O /tmp/keybase_amd64.deb
    sudo gdebi -n /tmp/keybase_amd64.deb
    draw_progress_bar 72

    # install mullvad
    echo -e "\n>>> installing mullvad vpn client <<<\n"
    wget https://mullvad.net/download/app/deb/latest -O /tmp/mullvad.deb
    sudo gdebi -n /tmp/mullvad.deb
    draw_progress_bar 73

    # install vlc
    echo -e "\n>>> installing vlc <<<\n"
    sudo apt-get install -y vlc
    draw_progress_bar 74

    # install xpad
    echo -e "\n>>> installing xpad <<<\n"
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
    sudo mkdir -p /etc/icons
    sudo chown `id -nu`:`id -ng` /etc/icons

    # install discord
    echo -e "\n>>> installing discord <<<\n"
    wget "https://discord.com/api/download?platform=linux&format=deb" -O /tmp/discord.deb
    # wget "https://dl.discordapp.net/apps/linux/0.0.14/discord-0.0.14.deb" -O /tmp/discord.deb
    sudo gdebi -n /tmp/discord.deb
    draw_progress_bar 78

    # install dolphin
    echo -e "\n>>> installing dolphin <<<\n"
    sudo apt-add-repository -y ppa:dolphin-emu/ppa
    sudo apt update
    sudo apt install -y dolphin-emu
    draw_progress_bar 80

    # install fusion
    echo -e "\n>>> installing fusion <<<\n"
    wget "https://www.carpeludum.com/download/kega-fusion_3.63-2_i386.deb" -O /tmp/kega-fusion.deb
    sudo gdebi -n /tmp/kega-fusion.deb
    draw_progress_bar 82

    # install mupen64plus
    echo -e "\n>>> installing mupen <<<\n"
    sudo apt-get install -y mupen64plus-qt
    draw_progress_bar 84

    # install nestopia
    echo -e "\n>>> installing nestopia <<<\n"
    sudo apt-get install -y nestopia
    draw_progress_bar 86

    # install pcsx-reloaded
    echo -e "\n>>> installing pcsx reloaded <<<\n"
    sudo apt-get install -y pcsxr
    wget "https://the-eye.eu/public/rom/Bios/psx/scph1001.zip" -O /tmp/scph1001.zip
    sudo mkdir -p /etc/ps_bios/psx
    sudo chown `id -nu`:`id -ng` /etc/ps_bios/psx
    unzip /tmp/scph1001.zip -d /etc/ps_bios/psx
    draw_progress_bar 88

    # install pcsx2
    echo -e "\n>>> installing pcsx2 <<<\n"
    sudo add-apt-repository -y ppa:gregory-hainaut/pcsx2.official.ppa
    sudo apt update
    sudo apt install -y pcsx2
    wget "https://the-eye.eu/public/rom/Bios/ps2/sony_ps2_%28SCPH39001%29.rar" -O /tmp/scph39001.rar
    sudo mkdir -p /etc/ps_bios/ps2
    sudo chown `id -nu`:`id -ng` /etc/ps_bios/ps2
    unrar x /tmp/scph39001.rar /etc/ps_bios/ps2
    draw_progress_bar 90

    # install redream   FIXME   installs broken
    echo -e "\n>>> installing redream <<<\n"
    wget "https://redream.io/download/redream.x86_64-linux-v1.5.0.tar.gz" -O /tmp/redream.tar.gz
    sudo mkdir -p /opt/redream
    sudo tar -C /opt/redream -xzf /tmp/redream.tar.gz
    [[ -f /etc/icons/Dreamcast.png ]] || desktop_icon Dreamcast Game /opt/redream/redream "https://cdn.pu.nl/article/dc_logo_black.png"
    menu_icon Redream Game /opt/redream/redream /etc/icons/dreamcast.jpg
    draw_progress_bar 92

    # install snes9x
    echo -e "\n>>> installing snes9x <<<\n"
    wget "https://sites.google.com/site/bearoso/snes9x/snes9x_1.60-1_amd64.deb" -O /tmp/snes9x.deb
    sudo gdebi -n /tmp/snes9x.deb
    draw_progress_bar 94

    # install steam
    echo -e "\n>>> installing steam <<<\n"
    wget "https://repo.steampowered.com/steam/archive/precise/steam_latest.deb" -O /tmp/steam.deb
    sudo gdebi -n /tmp/steam.deb
    draw_progress_bar 95

    # install wine
    echo -e "\n>>> installing wine <<<\n"
    wget -nc https://dl.winehq.org/wine-builds/winehq.key -O /tmp/winehq.key
    sudo apt-key add /tmp/winehq.key
    sudo add-apt-repository -y "deb https://dl.winehq.org/wine-builds/ubuntu/ focal main"
    sudo apt-get update
    sudo apt-get install -y --install-recommends winehq-stable
fi
draw_progress_bar 97


####################################
### install gaming desktop icons ###
####################################

if [[ -n "$game_icons" ]]; then
    echo -e "\n====== Installing Gaming Icons ======\n"

    # setup
    [[ -d /etc/icons ]] || { sudo mkdir -p /etc/icons; sudo chown `id -nu`:`id -ng` /etc/icons; }

    # discord
    desktop_icon Discord Game `which discord` "https://www.podfeet.com/blog/wp-content/uploads/2018/02/discord-logo.png"
    
    # dolphin
    desktop_icon GameCube Game `which dolphin-emu` "https://www.logolynx.com/images/logolynx/da/da85020e7769ecd41a5e3e7d313d3e0b.png"

    # fusion
    desktop_icon Genesis Game `which kega-fusion` "https://www.whatsageek.com/wp-content/uploads/2015/03/Sega-Logo-2.jpg"

    # mupen
    desktop_icon N64 Game `which mupen64plus-qt` "https://clipartart.com/images/n64-icon-clipart-4.png"

    # nestopia
    desktop_icon NES Game `which nestopia` "http://i2.wp.com/www.thegameisafootarcade.com/wp-content/uploads/2015/06/NES-logo.jpg?resize=526%2C297"
    
    # pcsx      FIXME   broken icon
    desktop_icon PSX Game `which pcsx` "https://openlab.citytech.cuny.edu/mgoodwin-eportfolio/files/2015/03/PSX-Logo.png"

    # pcsx2     FIXME   broken icon
    desktop_icon PS2 Game `which pcsx2` "https://www.logolynx.com/images/logolynx/ac/acd6d535d370fed0fbbe59ca9490524b.png"
    
    # redream   PEND   missing icon
    [[ -f /etc/icons/Dreamcast.png ]] || desktop_icon Dreamcast Game /opt/redream/redream "https://cdn.pu.nl/article/dc_logo_black.png"

    # snes9x    FIXME   broken icon
    desktop_icon SNES Game `which snes9x` "https://www.logolynx.com/images/logolynx/38/386765d9b96c11d0758d27cfc3b9bdee.png"

    # steam
    desktop_icon Steam Game `which steam` "https://cdn2.iconfinder.com/data/icons/zeshio-s-social-media/200/Social_Media_Icons_Edged_Highlight_16-16-512.png"
fi
draw_progress_bar 98


###################################
### install media desktop icons ###
###################################

if [[ -n "$media_icons" ]]; then
    echo -e "\n====== Installing Media Icons ======\n"

    # setup
    [[ -d /etc/icons ]] || { sudo mkdir -p /etc/icons; sudo chown `id -nu`:`id -ng` /etc/icons; }
    
    # Amazon
    desktop_link Amazon AudioVideo "https://www.amazon.com/Amazon-Video" "https://marketingland.com/wp-content/ml-loads/2014/08/amazon-blkwht-1920.png"

    # Discovery+
    desktop_link Discovery+ AudioVideo "https://www.discoveryplus.com" "https://cf.press.discovery.com/ugc/logos/2009/08/22/DSC_D_pos.png"

    # ESPN
    desktop_link ESPN AudioVideo "https://www.espn.com/watch/" "http://logok.org/wp-content/uploads/2015/02/ESPN-logo-wordmark.png"

    # HBO Max       FIXME   broken icon
    desktop_link HBO Max AudioVideo "https://play.hbomax.com/n" "https://hbomax-images.warnermediacdn.com/2020-05/square%20social%20logo%20400%20x%20400_0.png"

    # Netflix
    desktop_link Netflix AudioVideo "https://www.netflix.com/browse" "https://jobs.netflix.com/static/images/netflix_social_image.png"

    # Peacock
    desktop_link Peacock AudioVideo "https://www.peacocktv.com/watch/home" "http://logok.org/wp-content/uploads/2014/03/NBC-peacock-logo.png"

    # SportSurge
    desktop_link --ff SportSurge AudioVideo "https://sportsurge.net" "http://img3.wikia.nocookie.net/__cb20120228000316/logopedia/images/7/7e/Surge_logo2.jpg"

    # Spotify
    desktop_link Spotify AudioVideo "https://open.spotify.com/" "http://www.soft32.com/blog/wp-content/uploads/2016/08/spotify_logo.png"

    # VLC           FIXME   blackground
    desktop_icon VLC AudioVideo `which vlc` "https://clipground.com/images/vlc-icon-png-8.jpg"

    # VoloKit       FIXME   broken icon
    desktop_link --ff VoloKit AudioVideo "http://www.volokit.com/" "https://pngimg.com/uploads/vkontakte/vkontakte_PNG8.png"

    # YouTube       FIXME   broken icon
    desktop_link --ff YouTube AudioVideo "https://www.youtube.com/" "https://dwglogo.com/wp-content/uploads/2020/05/1200px-YouTube_logo.png"
fi
draw_progress_bar 100
destroy_scroll_area
