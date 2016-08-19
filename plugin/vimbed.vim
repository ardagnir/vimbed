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

let s:fromCommand = 0
let s:vim_mode = "n"


"Replacement for 'edit! s:file' that is undo joined (and doesn't leave the
"scratch buffer)
function! Vimbed_UndoJoinedEdit(file)
  if s:slice && (s:slice_start > 0 || s:slice_end < line("$") - 1)
    undojoin | exec "normal! \<ESC>".(s:slice_start+1)."gg\"_d".(s:slice_end+1)."gg"
    undojoin | exec "".s:slice_start."read ".a:file
  else
    undojoin | exec "normal! \<ESC>gg\"_dG"
    undojoin | exec "read ".a:file
    undojoin | normal! k"_dd
  endif
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
  call s:VerySilent("call Vimbed_UndoJoinedEdit('".s:GetUpdateFile()."')")

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
    if !s:slice || !s:WriteMetaFile(s:metaFile, 0)
      call s:WriteFile(0)
    endif
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
    if a:lineEnd-a:lineStart > 0
      call feedkeys((a:lineEnd-a:lineStart)."j",'n')
    endif
    call feedkeys ("0",'n')
    if a:columnEnd == 1 "Cursor is between previous line and this
      call feedkeys("k$",'n')
    elseif a:columnEnd > 2
      call feedkeys((a:columnEnd-2)."l",'n')
    endif
    if afterText
      call feedkeys("ol", 'n')
    endif
    call feedkeys("\<C-G>",'n')
  endif

  call system("echo '' > ".s:metaFile)
  let s:vim_mode=''
  if !s:slice || !s:WriteMetaFile(s:metaFile, 0)
    call s:WriteFile(0)
  endif
endfunction

function! s:GetContentsFile()
  if s:includeTabs
    return "/tmp/vimbed/".tolower(v:servername)."/contents-".bufnr('%').".txt"
  else
    return s:file
  endif
endfunction

function! s:GetUpdateFile()
  if s:includeTabs
    return "/tmp/vimbed/".tolower(v:servername)."/update-".bufnr('%').".txt"
  else
    return s:updateFile
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

  let s:includeTabs = 0
  let s:slice = 0
  for option in split(a:options, ",")
    if option == "tabs"
      let s:includeTabs = 1
    elseif option == "slice"
      let s:slice = 1
      let s:slice_start = 0
      let s:slice_end = 0
    else
      return 1
    endif
  endfor

  "Vim seems to be inconsistent with arrowkey terminal codes, even for the same termtype. So
  "we're setting them manually.
  exec "set t_ku=\<ESC>[A"
  exec "set t_kd=\<ESC>[B"
  exec "set t_kr=\<ESC>[C"
  exec "set t_kl=\<ESC>[D"

  snoremap <bs> <C-G>c
  snoremap <C-]> <Nop>

  "Contents of the vim buffer
  if s:slice
    let s:file = "/tmp/vimbed/".tolower(v:servername)."/slice.txt"
  else
    let s:file = "/tmp/vimbed/".tolower(v:servername)."/contents.txt"
  endif

  "Contents of the vim buffer

  "Vim metadata
  let s:metaFile = "/tmp/vimbed/".tolower(v:servername)."/meta.txt"

  "Messages from vim
  let s:messageFile = "/tmp/vimbed/".tolower(v:servername)."/messages.txt"

  "Put text in this file before telling vim to update
  let s:updateFile = "/tmp/vimbed/".tolower(v:servername)."/update.txt"

  "Tab info
  let s:tabFile = "/tmp/vimbed/".tolower(v:servername)."/tabs.txt"

  augroup vimbed
    sil autocmd!
    sil autocmd FileChangedShell * echon ''

    "I'm piping through cat, because write! can still trigger vim's
    "clippy-style 'are you sure?' messages.
    sil exec "sil autocmd TextChanged * call <SID>WriteFile(0)"

    "Adding text in insert mode calls this, but not TextChangedI
    sil exec "sil autocmd CursorMovedI * call <SID>WriteFile(0)"

    sil exec "autocmd CursorMoved * call <SID>WriteMetaFile('".s:metaFile."', 0)"
    sil exec "autocmd CursorMovedI * call <SID>WriteMetaFile('".s:metaFile."', 0)"

    sil exec "autocmd InsertEnter * call <SID>WriteMetaFile('".s:metaFile."', 1)"
    sil exec "autocmd InsertLeave * call <SID>WriteMetaFile('".s:metaFile."', 0)"
    sil exec "autocmd InsertChange * call <SID>WriteMetaFile('".s:metaFile."', 1)"
    sil exec "autocmd VimLeave * call <SID>VimLeave('".s:metaFile."')"

    if s:includeTabs
      sil exec "autocmd BufEnter * call <SID>WriteTabFile()"
      sil exec "autocmd TabEnter * call <SID>WriteTabFile()"
    endif
  augroup END
  return 0
endfunction

function! Vimbed_Poll()
  "WriteFile is only needed for games, shells, and other plugins that change
  "text without user input. Feel free to remove it if you don't use these.
  call s:WriteFile(0)

  call s:CheckConsole()
  call s:OutputMessages()
endfunction

let s:lastChangedTick = 0

function! s:WriteFile(force)
  if a:force || s:lastChangedTick != b:changedtick
    let s:lastChangedTick = b:changedtick
    "Force vim to add trailing newline to empty files
    if line('$') == 1 && getline(1) == ''
      call s:VerySilent('!echo "" > '.s:GetContentsFile())
    else
      if s:slice
        call s:VerySilent((s:slice_start+1) . ',' . (s:slice_end+1) . 'write !cat > '.s:GetContentsFile())
      else
        call s:VerySilent('write !cat > '.s:GetContentsFile())
      endif
    endif
    call s:OutputMessages()
  endif
endfunction

function! s:WriteMetaFile(fileName, checkInsert)
  if s:quitting == 1
    return 0
  endif
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

  let l:old_start=s:slice_start
  let l:old_end=s:slice_end

  if s:vim_mode ==# 'v' || s:vim_mode ==# 's'
    let vl = line('v')
    let vLine = getline('v')
    let vc = s:CharLength(vLine, col('v'))
    if l < vl || (l == vl && c < vc)
      let s:slice_start = l-1
      let s:slice_end = vl-1
      let line2 = "-,".(c-1).",".s:slice_start."\\n"
      let line3 = "-,".(vc).",".s:slice_end."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    else
      let s:slice_start = vl-1
      let s:slice_end = l-1
      let line2 = "-,".(vc-1).",".s:slice_start."\\n"
      let line3 = "-,".c.",".s:slice_end."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    endif
  elseif s:vim_mode ==# 'V' || s:vim_mode ==# 'S'
    let vl = line('v')
    if l < vl
      let s:slice_start = l-1
      let s:slice_end = vl
      let line2 = "-,".0.",".s:slice_start."\\n"
      let line3 = "-,".0.",".s:slice_end."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    else
      let s:slice_start = vl-1
      let s:slice_end = l
      let line2 = "-,".0.",".s:slice_start."\\n"
      let line3 = "-,".0.",".s:slice_end."\\n"
      call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
    endif
  elseif (s:vim_mode == 'n' || s:vim_mode[0] == 'R') && getline('.')!=''
    let s:slice_start = l-1
    let s:slice_end = l-1
    let line2 = "-,".(c-1).",".s:slice_start."\\n"
    let line3 = "-,".c.",".s:slice_end."\\n"
    call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
  else
    let s:slice_start = l-1
    let s:slice_end = l-1
    let line2 = "-,".(c-1).",".s:slice_start."\\n"
    let line3 = line2
    call system('echo -e "'.line1.line2.line3.'" > '.a:fileName)
  endif
  if s:slice && (s:slice_start != l:old_start || s:slice_end != l:old_end)
    call s:WriteFile(1)
    return 1
  else
    call s:OutputMessages()
    return 0
  endif
endfunction

let s:quitting = 0
function s:VimLeave(fileName)
  let s:quitting = 1
  if v:dying == 0
    call system('echo "quit" > '.a:fileName)
  endif
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
      call s:WriteFile(0)
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
      call system('echo c,'.getcmdpos().' > '.s:metaFile)
      call system('echo '.s:BetterShellEscape(cmdtype.cmdline).' >> '.s:metaFile)
      if &incsearch && (cmdtype == "?" || cmdtype == "/") && strlen(cmdline) > 0
        let startPos = searchpos(cmdline, 'bn')
        if startPos[0] <= 0
          let startPos = getpos('.')[1:2]
        endif
        let endPos = getpos('.')[1:2]

        let startl = startPos[0]
        let endl = endPos[0]
        let startc = s:CharLength(getline(startl), startPos[1])
        let endc = s:CharLength(getline(endl), endPos[1])
        if endPos[1] > strlen(getline(endl)) || endc == startc
          let endc += 1
        endif

        if startc >= 0 && endc >= 0
          let l:old_start=s:slice_start
          let l:old_end=s:slice_end

          let s:slice_start = startl-1
          let s:slice_end = startl-1

          let line3 = "-,".(startc-1).",".s:slice_start."\\n"
          let line4 = "-,".(endc-1).",".s:slice_end."\\n"

          call system('echo -e "'.line3.line4.'" >> '.s:metaFile)
          if s:slice && (s:slice_start != l:old_start || s:slice_end != l:old_end)
            call s:WriteFile(1)
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
