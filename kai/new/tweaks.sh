#!/bin/sh

#---Prompts

pkg (){
    while true; do
        echo
        read -p "$3 [y/N] " yn
        case "$yn" in
            [Yy]* ) packages="$packages $1" && $2=1 ; break ;;
            [Nn]* ) break ;;
            '') break ;;
            * ) echo 'Please answer "yes" or "no".'
        esac
    done
}

conf (){
    while true; do
        echo
        read -p "$2 [y/N] " yn
        case "$yn" in
            [Yy]* ) $1=1 break ;;
            [Nn]* ) break ;;
            '') break ;;
            * ) echo 'Please answer "yes" or "no".'
        esac
    done
}

# pacman
conf 'lib32' 'Do you wish to enable the lib32 repository?'
pkg 'lib32-artix-archlinux-support' 'arch_repos'  'Do you wish to enable the Arch repositories?'
pkg 'wget' 'chaotic_aur' 'Do you wish to enable the chaotic-AUR?'
conf 'pacman_colour' 'Do you wish to enable pacman colours?'
conf 'pacman_ilovecandy' 'Do you wish to enable pacman ILoveCandy?'
conf 'parallel_downloads' 'Do you wish to enable pacman parallel downloads?'
[[ "$parralel_downloads" -eq 1 ]] && read -p 'How many parallel downloads would you like to enable? ' parallel_downloads_num

# doas
pkg 'opendoas' 'install_doas' 'Do you wish to install doas?'
printf "\nYou can remove sudo as a security measure and symlink it to doas as to avoid breaking hardcoded software.\nShould you somehow break doas and are stuck without root priviledges, you can become root by using the 'su' command.\n"
[[ "$install_doas" -eq 1 ]] && conf 'remove_sudo' 'Do you wish to remove sudo?'
conf 'install_doasedit' 'Do you wish to install doasedit (doas equivalent for sudoedit)?'

# misc
printf '\nDISCLAIMER: blocking domains using the host file may break some sites.'
conf 'host_file_adblock' 'Do you wish to enable hosts file tracker blocking?'
printf '\nSometimes when using Artix you may experience a bug which breaks pulseaudio when using Chromium-based browsers.\nTo fix this issue, you can add "exit-idle-time = -1" to ~/.config/pulse/daemon.conf\nThis precaution is not necessary if you use pipewire.\n'
pkg 'pulseaudio' 'pulse_fix' 'Apply hacky solution which fixes it?'

# shell
pkg 'dash' 'enable_dash' 'Do you wish to switch sh (/bin/sh symlink) to dash?'
pkg 'zsh' 'chsh_zsh' 'Do you wish to switch your interactive shell to zsh?'

# AUR helpers
conf 'install_paru' 'Do you wish to install the paru AUR helper?'
conf 'install_yay' 'Do you wish to install the yay AUR helper?'


#---Install and configure

# pacman
[[ "$pacman_colour" -eq 1 ]] && sed -i 's/#Color/Color/' /etc/pacman.conf
[[ "$pacman_ilovecandy" -eq 1 ]] && grep -q 'ILoveCandy' /etc/pacman.conf || sed -i 's/# Misc options/# Misc options\nILoveCandy/' /etc/pacman.conf
[[ "$parallel_downloads" -eq 1 ]] && sed -i "s/#ParallelDownloads = 5/ParallelDownloads = $parallel_downloads_num/" /etc/pacman.conf
if [[ "$lib32" -eq 1 ]]; then
    [ "$(grep -w '\[lib32\]' /etc/pacman.conf)" = '#[lib32]' ] && sed -i 's/#[lib32]/[lib32]/' /etc/pacman.conf
    [ "$(grep -wA1 '\[lib32\]' /etc/pacman.conf | tail -1)" = '#Include = /etc/pacman.d/mirrorlist' ] &&
    grep -nwA1 '\[lib32\]' /etc/pacman.conf | tail -1 | cut -d'-' -f1 | $root_cmd xargs -I% sed -i '%s/#//' /etc/pacman.conf
fi
sudo pacman -Syu "$packages" --noconfirm --needed
[[ "$arch_repos" -eq 1 ]] && cat arch-repos.txt >> /etc/pacman.conf
if [[ "$chaotic_aur" -eq 1 ]]; then
    key="$(wget -qO- robots=off -U mozilla 'https://aur.chaotic.cx/' | grep 'pacman-key' | cut -d' ' -f4 | head -1)"
    pacman-key --recv-key "$key" --keyserver keyserver.ubuntu.com && pacman-key --lsign-key "$key"
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf
fi
sudo pacman -Syy # never do this if there are available upgrades - this is only safe because we previously upgraded all the packages

# shell
[[ "$binsh_dash" -eq 1 ]] && ln -sfT /bin/dash /bin/sh && cp bash2dash.hook /usr/share/libalmpm/hooks
[[ "$chsh_zsh" -eq 1 ]] && chsh -s /bin/zsh

# AUR helpers
if [[ "$install_paru" ]]; then
    sudo pacman -S base-devel git --noconfirm --needed
    git clone https://aur.archlinux.org/paru.git install_paru
    sh -c 'cd install_paru && makepkg -si'
    yes | paru -S paru-bin
    sudo rm -rf install_paru
fi
if [[ "$install_yay" ]]; then
    sudo pacman -S base-devel git --noconfirm --needed
    git clone https://aur.archlinux.org/yay.git install_yay
    sh -c 'cd install_yay && makepkg -si'
    yes | yay -S yay-bin
    sudo rm -rf install_yay
fi

# misc
[[ "$pulse_fix" -eq 1 ]] && mkdir -p "$HOME/.config/pulse" && echo 'exit-idle-time = -1' > "$HOME/.config/pulse/daemon.conf"
[[ "$host_file_adblock" -eq 1 ]] && cat hosts >> /etc/hosts

# doas
[[ "$install_doas" -eq 1 ]] && echo 'permit persist :wheel' > /etc/doas.conf && chown -c root:root '/etc/doas.conf' && chmod 0444 '/etc/doas.conf'
[[ "$install_doasedit" -eq 1 ]] && curl -sL 'https://raw.githubusercontent.com/koalagang/doasedit/main/doasedit' -o /usr/bin/doasedit && chmod +x /usr/bin/doasedit
[[ "$remove_sudo" -eq 1 ]] && pacman -R sudo && ln -s /usr/bin/doas /usr/bin/sudo
