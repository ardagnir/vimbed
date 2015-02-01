" Vimbed
" A plugin for embedding vim
"
" Copyright (C) 2014, James Kolb <jck1089@gmail.com>
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU Affero General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
" 
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU Affero General Public License for more details.
" 
" You should have received a copy of the GNU Affero General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.

let g:save_cpo = &cpo
set cpo&vim
if exists("g:loaded_vimbed")
  finish
endif

let s:fromCommand = 0
let s:vim_mode = "n"


"Replacement for 'edit! s:file' that is undo joined (and doesn't leave the
"scratch buffer)
function! Vimbed_UndoJoinedEdit(file)
  undojoin | exec "normal! \<ESC>gg\"_dG"
  undojoin | exec "read ".a:file
  undojoin | normal! k"_dd
endfunction

"Gets chars instead of bytes.
function! s:CharLength(string, pos)
  if a:pos >= 0
    return strlen(substitute(strpart(a:string, 0, a:pos), ".", "x", "g"))
  else
    return strlen(substitute(a:string, ".", "x", "g"))
  endif
endfunction

function! Vimbed_UpdateText(lineStart, columnStart, lineEnd, columnEnd, preserveMode)
  call s:VerySilent("call Vimbed_UndoJoinedEdit('".s:GetContentsFile()."')")

  "This block of code handles unicode. Our input is in characters but vim
  "deals in bytes.
  let currentCol = a:columnStart
  let theLine = getline(a:lineStart)
  if s:CharLength(theLine, -1) < a:columnStart
    let afterText = 1
    call cursor(a:lineStart, strlen(theLine)+1)
  else
    let afterText = 0
    let actualColumn = s:CharLength(theLine, currentCol)
    while actualColumn < a:columnStart
      let currentCol += a:columnStart - actualColumn
      let actualColumn = s:CharLength(theLine, currentCol)
    endwhile
    call cursor(a:lineStart, currentCol)
  endif

  if a:preserveMode
    return
  endif

  if a:lineStart==a:lineEnd && a:columnStart==a:columnEnd
    if mode()=="n" || mode()=="v" || mode()=="V" || mode()=="s" || mode()=="S" || mode()=="c"
      if !afterText
        call feedkeys("\<ESC>i\<C-G>u",'n')
      else
        call feedkeys("\<ESC>a\<C-G>u",'n')
      endif
    else
        call feedkeys("\<C-G>u",'n')
    endif
  else
    call feedkeys ("\<ESC>0",'n')
    if a:columnStart>1
      call feedkeys ((a:columnStart-1)."l",'n')
    endif
    call feedkeys("\<ESC>v",'n')
    if a:columnEnd-a:columnStart > 1
      call feedkeys((a:columnEnd-a:columnStart-1)."l",'n')
    elseif a:columnStart-a:columnEnd > -1
      call feedkeys((a:columnStart-a:columnEnd+1)."h",'n')
    endif
    if a:lineEnd-a:lineStart > 0
      call feedkeys((a:lineEnd-a:lineStart)."j",'n')
    endif
    if afterText
      call feedkeys("ol", 'n')
    endif
    call feedkeys("\<C-G>",'n')
  endif

  call system("echo '' > ".s:metaFile)
  let s:vim_mode=''
endfunction

function! s:GetContentsFile()
  if s:includeTabs
    return "/tmp/vimbed/".tolower(v:servername)."/contents-".bufnr('%').".txt"
  else
    return s:file
  endif
endfunction

function! Vimbed_SetupVimbed(path, options)
  set noswapfile
  set shortmess+=A
  set noshowmode
  if a:path==""
    set buftype=nofile
    set bufhidden=hide
  else
    exec "edit ".a:path
  endif

  if index(split(a:options,","),"tabs")!=-1
    let s:includeTabs=1
  else
    let s:includeTabs=0
  endif

  "Vim seems to be inconsistent with arrowkey terminal codes, even for the same termtype. So
  "we're setting them manually.
  exec "set t_ku=\<ESC>[A"
  exec "set t_kd=\<ESC>[B"
  exec "set t_kr=\<ESC>[C"
  exec "set t_kl=\<ESC>[D"

  snoremap <bs> <C-G>c

  let s:file = "/tmp/vimbed/".tolower(v:servername)."/contents.txt"
  let s:metaFile = "/tmp/vimbed/".tolower(v:servername)."/meta.txt"
  let s:messageFile = "/tmp/vimbed/".tolower(v:servername)."/messages.txt"
  let s:tabFile = "/tmp/vimbed/".tolower(v:servername)."/tabs.txt"

  augroup vimbed
    sil autocmd!
    sil autocmd FileChangedShell * echon ''

    "I'm piping through cat, because write! can still trigger vim's
    "clippy-style 'are you sure?' messages.
    sil exec "sil autocmd TextChanged * call <SID>WriteFile()"

    "Adding text in insert mode calls this, but not TextChangedI
    sil exec "sil autocmd CursorMovedI * call <SID>WriteFile()"

    sil exec "autocmd CursorMoved * call <SID>WriteMetaFile('".s:metaFile."', 0)"
    sil exec "autocmd CursorMovedI * call <SID>WriteMetaFile('".s:metaFile."', 0)"

    sil exec "autocmd InsertEnter * call <SID>WriteMetaFile('".s:metaFile."', 1)"
    sil exec "autocmd InsertLeave * call <SID>WriteMetaFile('".s:metaFile."', 0)"
    sil exec "autocmd InsertChange * call <SID>WriteMetaFile('".s:metaFile."', 1)"
    if s:includeTabs
      sil exec "autocmd BufEnter * call <SID>WriteTabFile()"
      sil exec "autocmd TabEnter * call <SID>WriteTabFile()"
    endif
  augroup END
endfunction

function! Vimbed_Poll()
  "WriteFile is only needed for games, shells, and other plugins that change
  "text without user input. Feel free to remove it if you don't use these.
  call s:WriteFile()

  call s:CheckConsole()
  call s:OutputMessages()
endfunction

let s:lastChangedTick = 0

function! s:WriteFile()
  if s:lastChangedTick != b:changedtick
    let s:lastChangedTick = b:changedtick
    "Force vim to add trailing newline to empty files
    if line('$') == 1 && getline(1) == ''
      call s:VerySilent('!echo "" > '.s:GetContentsFile())
    else
      call s:VerySilent('write !cat > '.s:GetContentsFile())
    endif
    call s:OutputMessages()
  endif
endfunction

function! s:WriteMetaFile(fileName, checkInsert)
  if a:checkInsert
    if v:insertmode ==? 'i'
      let s:vim_mode = 'i'
    "Insertmode codes are different than mode() codes
    elseif v:insertmode ==? 'r'
      let s:vim_mode = 'R'
    elseif v:insertmode ==? 'v'
      let s:vim_mode = 'Rv'
    endif
  else
    let s:vim_mode = mode()
  endif

  let line1 = s:vim_mode."\\n"

  let l = line('.')
  let theLine = getline('.')
  let c = s:CharLength(theLine, col('.'))
  if col('.') > strlen(theLine)
    let c += 1
  endif

  if s:vim_mode ==# 'v' || s:vim_mode ==# 's'
    let vl = line('v')
    let vLine = getline('v')
    let vc = s:CharLength(theLine, col('v'))
    if l < vl || (l == vl && c < vc)
      let line2 = "-,".(c-1).",".(l-1)."\\n"
      let line3 = "-,".(vc).",".(vl-1)."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    else
      let line2 = "-,".(vc-1).",".(vl-1)."\\n"
      let line3 = "-,".c.",".(l-1)."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    endif
  elseif s:vim_mode ==# 'V' || s:vim_mode ==# 'S'
    let vl = line('v')
    if l < vl
      let line2 = "-,".0.",".(l-1)."\\n"
      let line3 = "-,".0.",".(vl)."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    else
      let line2 = "-,".0.",".(vl-1)."\\n"
      let line3 = "-,".0.",".l."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    endif
  elseif (s:vim_mode == 'n' || s:vim_mode[0] == 'R') && getline('.')!=''
    let line2 = "-,".(c-1).",".(l-1)."\\n"
    let line3 = "-,".c.",".(l-1)."\\n"
    call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
  else
    let line2 = "-,".(c-1).",".(l-1)."\\n"
    let line3 = line2
    call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
  endif
  call s:OutputMessages()
endfunction

let s:tabsChanging=0

function s:WriteTabFile()
  if s:tabsChanging
    return
  endif

  let output=bufnr('%')." ".tabpagenr()
  for i in range(tabpagenr('$'))
    let bufnum = tabpagebuflist(i+1)[0]
    let output .= "\n".bufnum.":".s:BetterShellEscape(expand('#'.bufnum.":p"))
  endfor
  call system("echo -n '".output."' > ".s:tabFile)
endfunction

function! Vimbed_UpdateTabs(activeTab, tabList, loadFiles)
  let oldNumTabs=tabpagenr('$')
  let s:tabsChanging=1
  let currentFile=0
  tablast

  "Add new tabs
  for path in a:tabList
    if type(path)==1 "Is path a string?
      exec "tabedit ".path
    else "A passed in number means a buffer
      exec "tabedit"
      if path>=1
        exec "b".path
      endif
    endif
    if a:loadFiles
      let fileName="/tmp/vimbed/".tolower(v:servername)."/tabin-".currentFile.".txt"
      call s:VerySilent("call Vimbed_UndoJoinedEdit('".fileName."')")
      call s:WriteFile()
      call system("rm ".fileName)
      let currentFile+=1
    endif
  endfor

  "Delete old tabs
  for i in range(oldNumTabs)
    tabclose! 1
  endfor

  exec "tabnext ".a:activeTab

  let s:tabsChanging=0
  call s:WriteTabFile()
endfunction

function s:BetterShellEscape(text)
  let returnVal = shellescape(a:text, 1)
  let returnVal = substitute(returnVal, '\\%', '%', 'g')
  let returnVal = substitute(returnVal, '\\#', '#', 'g')
  let returnVal = substitute(returnVal, '\\!', '!', 'g')
  return returnVal
endfunction

function! s:CheckConsole()
    let cmdtype = getcmdtype()
    let cmdline = getcmdline()
    if cmdtype != "" "If you enter command mode from visual, mode()=='v', not 'c'
      call system('echo c > '.s:metaFile)
      call system('echo '.s:BetterShellEscape(cmdtype.cmdline).' >> '.s:metaFile)
      if &incsearch && (cmdtype == "?" || cmdtype == "/") && strlen(cmdline) > 0
        let startPos = searchpos(cmdline, 'bn')
        if startPos[0] >= 0
          let endPos = getpos('.')[1:2]

          let startl = startPos[0]
          let endl = endPos[0]
          let startc = s:CharLength(getline(startl), startPos[1])
          let endc = s:CharLength(getline(endl), endPos[1])
          if endc == startc
            let endc += 1
          endif

          let line3 = "-,".(startc-1).",".(startl-1)."\\n"
          let line4 = "-,".(endc-1).",".(endl-1)."\\n"
          if startc >= 0 && endc >= 0
            call system('echo -e "'.line3.line4.'" >> '.s:metaFile)
          endif
        endif
      endif

      let s:vim_mode="c"
    else
      if mode() != s:vim_mode
        call s:WriteMetaFile(s:metaFile, 0)
      endif
    endif
endfunction

"Don't even redirect the output
function! s:VerySilent(args)
  redir END
  silent exec a:args
  exec "redir! >> ".s:messageFile
endfunction

"This repeatedly flushes because messages aren't written until the redir ends.
"Also used to trigger stdout (otherwise the messages might be delayed)
function! s:OutputMessages()
  redir END
  echo ''
  exec "redir! >> ".s:messageFile
endfunction

let g:loaded_vimbed = 1

let &cpo = g:save_cpo
unlet g:save_cpo
