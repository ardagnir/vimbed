Vimbed
=========

Vimbed is a Vim plugin for embedding Vim in other programs. Run Vim in the background using Vimbed to ease communication with external processes.

## Projects that use Vimbed
- [Athame](http://github.com/ardagnir/athame) patches GNU Readline to embed Vim in bash, gdb, python, etc. Athame can also be used to patch Zsh to add Vim.
- [Pterosaur](http://github.com/ardagnir/pterosaur) embeds Vim in Firefox textboxes. *(No longer maintained)*
- [Chalcogen](http://github.com/ardagnir/chalcogen) embeds Vim in the Atom editor. *(Experimental. Not maintained)*

## Requirements
- Vimbed requires Vim with +clientserver.
- Vimbed works best in GNU/Linux.
- Vimbed also works in OSX, but doing so requires XQuartz. *(This is a requirement of vim's +clientserver functionality.)*

## Installation
Install vimbed with your favorite plugin-manager. If you use pathogen:

    cd ~/.vim/bundle
    git clone http://github.com/ardagnir/vimbed

Note that vimbed won't be very useful without another process to communicate with.

## API
Coming eventually. Until then, see Athame, Pterosaur, and Chalcogen for examples.

## License
AGPL v3
