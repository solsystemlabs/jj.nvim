if exists('g:loaded_jj_nvim') || &cp
  finish
endif
let g:loaded_jj_nvim = 1

command! JJToggle lua require('jj-nvim').toggle()
command! JJLog lua require('jj-nvim').show_log()
command! JJClose lua require('jj-nvim').close()
command! -nargs=1 JJRevset lua require('jj-nvim').set_revset(<q-args>)
command! JJRevsetMenu lua require('jj-nvim').show_revset_menu()

nnoremap <silent> <Plug>(jj-nvim-toggle) :JJToggle<CR>

if !hasmapto('<Plug>(jj-nvim-toggle)') && maparg('<leader>ji', 'n') ==# ''
  nmap <leader>ji <Plug>(jj-nvim-toggle)
endif
