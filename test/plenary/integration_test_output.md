
### go_back_to_value_from_elsewhere_no_remind
expected: _NO_ reminder
require  


a
### nonexistent_abbr_no_remind
expected: _NO_ reminder
nothing 


a
### single_reminds
expected: YES reminder
neovim 


a
### nk_in_val_reminds
expected: YES reminder
application programming interface 


a
### if_bs_in_value_reminds
expected: YES reminder
goodbye 


a
### normal_mode_modifies_value_reminds
expected: YES reminder
require 


a
### expanded_not_reminded
expected: _NO_ reminder
require 


a
### expanded_midline_not_reminded
expected: _NO_ reminder
something on require line 


a
### does_nothing_on_normal_mode
expected: _NO_ reminder



