# squeel.nvim

A simple nvim plugin that brings inline SQL syntax highlighting and formatting to python files

Heavily inspired by [TJ DeVries youtube video on how to format embedded languaged in NeoVim](https://www.youtube.com/watch?v=v3o9YaHBM4Q)

## Requirements

- Python 3.8+ ... to create virtual environment for sqlparse formatting tool
- Plenary ... for cross platform path operations related to python venv
- treesitter with languages `python` and `sql` installed

## Usage

Install it and use its `format()` function to inline format the python code

Using lazy package manager:

```lua
return {
    "OleJoik/squeel.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter"
    },
    config = function()
        local squeel = require("squeel")
        squeel.setup()

        vim.keymap.set("n", "<leader>fo", function()
            -- optionally pass a buffer id to the format function
            squeel.format()
        end)
    end,
}
```

Add a `-- sql` comment in the start of the sql-string for the treesitter to detect it for formatting and syntax highlighting. For example, if you have this...

```python
stmt = """ -- sql
    SELECT * FROM my_table t WHERE t.id = '123'
"""
```

... then running `:lua require("squeel").format()` yields this formatted code:

```python
stmt = """ -- sql
    SELECT *
    FROM my_table t
    WHERE t.id = '123'
"""
```


### Limitations

Can not be used with python f-strings as the sql treesitter language doesn't know how to deal with this syntax.

It's quite dangerous to do this, so you probably shouldn't do it anyway.

```python
# DONT DO THIS.
user_provided_id = "very_dangerous"
stmt = f"""
    SELECT * FROM my_table t WHERE t.id = '{user_provided_id}'
"""
```

