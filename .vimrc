syntax on
set mouse=a

set number " nu
set tabstop=4 " ts
set shiftwidth=4 " sw
set softtabstop=4 " sts
set autoindent " ai
set smartindent " si
set wrap
set hlsearch
set ignorecase
set smartcase
set smarttab
set magic
set showmatch
set cursorline

filetype indent on


" run code
augroup compileandrun
    autocmd!
    autocmd filetype python nnoremap <F5> :w <bar> :!py % <cr>
    autocmd filetype cpp nnoremap <F5> :w <bar> !g++ % -o %< && ./%< <cr>
augroup END
