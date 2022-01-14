### Table of Contents
+ [Usecase](#usecase)
+ [Installation](#installation)
+ [Example](#example)
+ [API](#api)
+ [Frontends](#frontends)

### Usecase
Provides hooks for abbreviation events which fire on abbreviation expansion or when an abbreviation's value has been typed but the user did not take advantage of the abbreviation functionality.


### Installation

```lua
use {
    '0styx0/abbremand.nvim',
    module = 'abbremand' -- if want to lazy load
}
```


### Example

```lua
local abbremand = require('abbremand')
abbremand.on_abbr_forgotten(function(abbr_data)

    print(abbr_data.trigger)

    abbr_data.on_change(function(updated_text)
        print('user changed '..abbr_data.value..' to '..updated_text)
    end)
end)
```

### API
+ `on_abbr_forgotten({trigger, value, row, col, col_end, on_change: Function})`
+ `on_abbr_remembered({trigger, value, row, col, col_end, on_change: Function})`
+ `on_change(updated_text)`
    + Passed as part of `on_abbr_x`, not directly exposed

### Frontends
+ [abbreinder.nvim](https://github.com/0styx0/abbreinder.nvim)
    + Reminds user when they forget abbreviations
