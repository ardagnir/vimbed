Vimbed
=========

Vimbed is a Vim plugin for embedding Vim in other programs. Run Vim in the background using Vimbed to ease communication with external processes.

##Projects that use Vimbed
- [Pterosaur](http://github.com/ardagnir/pterosaur) embeds Vim in Firefox textboxes.
- [Chalcogen](http://github.com/ardagnir/chalcogen) embeds Vim in the Atom editor. *(Currently unstable)*

##Requirements
- Vimbed requires Vim with +clientserver.
- Vimbed works best in GNU/Linux.
- Vimbed also works in OSX, but doing so requires XQuartz. *(This is a requirement of vim's +clientserver functionality.)*

##Installation
Install vimbed with your favorite plugin-manager. If you use pathogen:

    cd ~/.vim/bundle
    git clone http://github.com/ardagnir/vimbed

Note that vimbed won't be very useful without another process to communicate with.

##API
Comming soon. Until then, see Pterosaur and Chalcogen for examples.

##License
AGPL v3
