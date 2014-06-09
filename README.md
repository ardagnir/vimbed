Shadowvim
=========

Shadowvim is a Vim plugin for embedding Vim in other programs. Run Vim in the background using Shadowvim to ease communication with external processes.

##Projects that use Shadowvim
- [Pterosaur](http://github.com/ardagnir/pterosaur) embeds Vim in Firefox textboxes.
- [Chalcogen](http://github.com/ardagnir/chalcogen) embeds Vim in the Atom editor. *(Currently unstable)*


##Requirements
- Shadowvim requires Vim with +clientserver.
- Shadowvim works best in GNU/Linux.
- Shadowvim also works in OSX, but doing so requires XQuartz. *(This is a requirement of vim's +clientserver functionality.)*

##Installation
Install shadowvim with your favorite plugin-manager. If you use pathogen:

    cd ~/.vim/bundle
    git clone http://github.com/ardagnir/shadowvim

Note that shadowvim won't be very useful without another process to communicate with.

##API
Comming soon. Until then, see Pterosaur and Chalcogen for examples.

##License
AGPL v3
