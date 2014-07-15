" =============================================================================
" File: wildfire.vim
" Description: Smart selection of the closest text object
" Mantainer: Giacomo Comitti (https://github.com/gcmt)
" Url: https://github.com/gcmt/wildfire.vim
" License: MIT
" =============================================================================


let s:save_cpo = &cpo
set cpo&vim


" Internal variables
" =============================================================================

let s:cannot_be_nested = {"iw" : 1, "aw" : 1, "iW" : 1, "aW": 1}

let s:vim_text_objects = {}
for char in split("(){}[]<>'`\"bBwWpst", "\\zs")
    let s:vim_text_objects = extend(s:vim_text_objects, {"a".char : 1, "i".char : 1})
endfor

let s:counts = {}
let s:selections_history = []
let s:origin = []


" Functions
" =============================================================================

fu! s:LoadObjects(objects)
    " force `g:wildfire_objects` to be a dictionary
    let _objects = type(a:objects) == type([]) ? {"*": a:objects} : a:objects
    " split filetypes that share the same text objects
    for [ftypes, objs] in items(_objects)
        for ft in split(ftypes, ",")
            let _objects[ft] = objs
        endfor
    endfor
    return _objects
endfu

fu! s:Init(objects)
    let s:origin = getpos(".")
    let s:selections_history = []
    let s:counts = {}
    let _objects = s:LoadObjects(a:objects)
    for object in get(_objects, &ft, get(_objects, "*", []))
        let s:counts[object] = 1
    endfor
endfu

fu! wildfire#Start(repeat, objects)
    cal s:Init(a:objects)
    cal wildfire#Fuel(a:repeat)
endfu

fu! wildfire#Fuel(repeat)
    for i in range(a:repeat)
        cal s:SelectTextObject()
    endfor
endfu

fu! wildfire#Water(repeat)
    for i in range(a:repeat)
        cal setpos(".", s:origin)
        if len(s:selections_history) > 1
            let s:counts[remove(s:selections_history, -1).object] -= 1
            cal s:Select(get(s:selections_history, -1))
        endif
    endfor
endfu

fu! s:SelectTextObject()

    cal setpos(".", s:origin)

    let view = winsaveview()

    let candidates = {}
    for object in keys(s:counts)

        let to = {"object": object, "count": s:counts[object]}

        let [startline, startcol, endline, endcol] = s:Edges(to)
        let to = extend(to, {"startline": startline, "startcol": startcol,
            \ "endline": endline, "endcol": endcol })

        cal winrestview(view)

        " Some text object cannot be nested. This avoids unwanted behavior.
        if get(s:cannot_be_nested, to.object) && to.count > 1
            continue
        endif

        " The selection failed with the candidate text object
        if to.startline == to.endline && to.startcol == to.endcol
            continue
        endif

        " Sometimes Vim selects text objects even if the cursor is outside the
        " them (e.g. `it`, `i"`, etc). We don't want this.
        let cursor_col = s:origin[2]
        if to.startline == to.endline && (cursor_col < to.startcol || cursor_col > to.endcol)
            let s:counts[object] += 1
            continue
        endif

        let size = s:Size(to)

        " This happens when the _count is incremented but the selection remains still
        let _to = extend(copy(to), {"count": to.count-1})
        if s:AlreadySelected(_to)
            continue
        endif

        " Special case
        if object =~ "a\"\\|i\"\\|a'\\|i'" && startline == endline
            let _to = extend(copy(to), {"count": to.count-1, "startcol": to.startcol+1, "endcol": to.endcol-1})
            if s:AlreadySelected(_to)
                " When there is no more string to select on the same line, vim
                " selects the outer string text object. This is far from the
                " desired behavior
                continue
            endif
            let _to = extend(copy(to), {"count": to.count-1, "startcol": to.startcol+1})
            if s:AlreadySelected(_to)
                " This follows the previous check. When the string ends the
                " line, the size of the text object is just one character less
                continue
            endif
            let quote = strpart(object, 1)
            let [before, after] = [getline("'<")[:to.startcol-3], getline("'<")[to.endcol+1:]]
            if s:OddQuotes(quote, before) || s:OddQuotes(quote, after)
                continue
            endif
        endif

        let candidates[size] = to

    endfor

    cal s:SelectBestCandidate(candidates)

endfu

" To select the closest text object among the candidates
fu! s:SelectBestCandidate(candidates)
    if len(a:candidates)
        let to = a:candidates[min(keys(a:candidates))]
        let s:selections_history = add(s:selections_history, to)
        let s:counts[to.object] += 1
        cal s:Select(to)
    elseif len(s:selections_history)
        " get stuck on the last selection
        cal s:Select(get(s:selections_history, -1))
    else
        " do nothing
        exec "sil! norm! \<ESC>"
    endif
endfu

" To retrun the edges of a text object
fu! s:Edges(to)
    cal s:Select(a:to)
    exe "sil! norm! \<ESC>"
    return [line("'<"), col("'<"), line("'>"), col("'>")]
endfu

" To select a text object
fu! s:Select(to)
    exe "sil! norm! \<ESC>v\<ESC>v"
    if get(s:vim_text_objects, a:to.object)
        " use counts when selecting vim text objects
        exe "sil! norm! " . a:to.count . a:to.object
    else
        " counts might not be suported by non-defautl text objects
        for n in range(a:to.count)
            exe "sil! norm " . a:to.object
        endfor
    endif
endfu

" To check if a text object has been already selected
fu! s:AlreadySelected(to)
    return index(s:selections_history, a:to) >= 0
endfu

" To return the size of a text object
fu! s:Size(to)
    if a:to.startline == a:to.endline
        let line = getline(a:to.startline)
        return strlen(strpart(line, a:to.startcol, a:to.endcol-a:to.startcol+1))
    endif
    let size = strlen(strpart(getline(a:to.startline), a:to.startcol))
    let size += strlen(strpart(getline(a:to.endline), 0, a:to.endcol))
    let size += winwidth(0) * abs(a:to.startline - a:to.endline)  " good enough
    return size
endfu

" To check if in a strings there is an odd number of quotes
fu! s:OddQuotes(quote, s)
    let n = 0
    for i in range(0, strlen(a:s))
        if a:s[i] == a:quote && !(i > 0 && a:s[i-1] == "\\")
            let n += 1
        endif
    endfor
    return n % 2 != 0
endfu

" Quick Select
" =============================================================================

fu! wildfire#QuickSelect(objects)
    cal s:Init(a:objects)
    while 1
        let last_hist_size = len(s:selections_history)
        cal s:SelectTextObject()
        let sel = get(s:selections_history, -1)
        if empty(sel)
            return
        end
        if sel.startline < line("w0")
            cal wildfire#Water(1)
            break
        end
        if last_hist_size == len(s:selections_history)
            break
        end
    endw
    exe "norm! \<ESC>"
    cal setpos(".", s:origin)
    let save_hl = s:colors_of("Error")
    hi Error None
    let marks = s:show_marks(s:selections_history)
    cal s:jump(marks)
    sil exe "hi Error" save_hl
endfu

" To display marks
fu s:show_marks(selections)
    try | undojoin | catch | endtry
    cal matchadd("WildfireShade", '\%>'.(line('w0')-1).'l\%<'.line('w$').'l')
    let marks = split(g:wildfire_marks, '\zs')
    let candidates = {}
    for sel in a:selections
        if empty(marks) | break | end
        let mark = remove(marks, 0)
        let line = getline(sel.startline)
        let candidates[mark] = [sel, line[sel.startcol-1]]
        cal setline(sel.startline, s:str_subst(line, sel.startcol-1, mark))
        cal matchadd("WildfireMark", '\%'.sel.startline.'l\%'.sel.startcol.'c')
    endfor
    setl nomodified
    return candidates
endfu

" To ask the user where to jump and move there
fu s:jump(marks)
    if empty(a:marks) | return | end
    normal! m'
    while 1
        redraw
        cal s:show_prompt()
        let choice = s:get_char()
        if choice =~ "<C-C>\\|<ESC>" | cal s:clear_marks(a:marks)| break | end
        if has_key(a:marks, choice)
            cal s:clear_marks(a:marks)
            cal s:Select(a:marks[choice][0])
            let new_hist = s:selections_history[:index(split(g:wildfire_marks, '\zs'), choice)]
            let s:selections_history = new_hist
            break
        end
    endw
endfu

" To display the prompt
fu s:show_prompt()
    echohl WildfirePrompt | echon g:wildfire_prompt | echohl None
endfu


" To clear all marks
fu s:clear_marks(marks)
    cal s:clear_matches("WildfireMark", "WildfireShade")
    try | undojoin | catch | endtry
    for [sel, oldchar] in values(a:marks)
        cal setline(sel.startline, s:str_subst(getline(sel.startline), sel.startcol-1, oldchar))
    endfor
    setl nomodified
endfu

" Utilities
" =============================================================================

" To get the colors of given highlight group
" Note: does not handle linked groups
fu s:colors_of(group)
    redir => raw_hl | exe "hi" a:group | redir END
    if match(raw_hl, 'cleared') > 0
        return "None"
    end
    return substitute(matchstr(raw_hl, '\v(xxx)@<=.*'), "\n", " ", "")
endfu

" To clear matches of given groups
fu s:clear_matches(...)
    let groups = join(map(copy(a:000), "'^'.v:val.'$'"), '\|')
    for m in getmatches()
        if m.group =~# groups
            cal matchdelete(m.id)
        end
    endfor
endfu

" To substitute a character in a string
fu s:str_subst(str, col, char)
    return strpart(a:str, 0, a:col) . a:char . strpart(a:str, a:col+1)
endfu

" To get a key pressed by the user
fu s:get_char()
    let char = strtrans(getchar())
        if char == 13 | return "<CR>"
    elseif char == 27 | return "<ESC>"
    elseif char == 9 | return "<TAB>"
    elseif char >= 1 && char <= 26 | return "<C-" . nr2char(char+64) . ">"
    elseif char != 0 | return nr2char(char)
    elseif match(char, '<fc>^D') > 0 | return "<C-SPACE>"
    elseif match(char, 'kb') > 0 | return "<BS>"
    elseif match(char, 'ku') > 0 | return "<UP>"
    elseif match(char, 'kd') > 0 | return "<DOWN>"
    elseif match(char, 'kl') > 0 | return "<LEFT>"
    elseif match(char, 'kr') > 0 | return "<RIGHT>"
    elseif match(char, 'k\\d\\+') > 0 | return "<F" . match(char, '\\d\\+', 4)] . ">"
    end
endfu

" =============================================================================

let &cpo = s:save_cpo
unlet s:save_cpo
