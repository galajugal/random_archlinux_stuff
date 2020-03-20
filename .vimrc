set number
syntax on
filetype indent plugin on
set shiftwidth=4
set foldmethod=syntax
set nofoldenable

"set mousemodel=popup

let g:netrw_banner = 0
let g:netrw_winsize = 20

augroup python_folding_indent
  autocmd!
  autocmd FileType python set foldmethod=indent nofoldenable
augroup END

"%s/\/\*.*\*\///g
":%s/\s\+$//gce
"e flag shows no errors
