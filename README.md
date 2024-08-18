# gh-actions.nvim

> [!Warning]
> This plugin is a work in progress and might have bugs and breaking changes

## Run gh actions directly from neovim
Are you tired of visiting github in the browser to run your workflows or perhaps you use the CLI but remembering all the names and inputs is hard. Then this tool is for you, run workflows directly from neovim.

## Motivation
As a developer using Neovim for (almost) everything I needed a plugin for running github actions

## Features

- Run github actions: Trigger workflow_dispatch jobs while being able to see the expected inputs
- List workflow runs: List and see the statuses of workflow runs in your repository

## Setup

### Without options
```lua
-- lazy.nvim
{
  "GustavEikaas/gh-actions.nvim",
  config = function()
    require("gh-actions").setup()
  end
}
```

## Commands

### Vim commands
```
Actions run
Actions list
```

### List

![image](https://github.com/user-attachments/assets/355ff0a1-e25b-4c94-b4be-68375d2963b7)
### Auto refresh enabled when workflow is still running
![image](https://github.com/user-attachments/assets/5b34031b-24db-4710-9a92-f15afd7f63f7)
### Automatic stack trace on failed workflow run
![image](https://github.com/user-attachments/assets/dc034b8d-4f6b-4549-81df-0fdf0200dbf8)


#### Keymap

- `<leader>r` -> refresh
- `<leader>o` -> open details

### Run
Trigger workflow_dispatch events directly from neovim

1. :Actions run
2. `<leader>r` on your desired workflow
3. The yaml definition is shown in the left float, the arguments for triggering is showed in the right float.
4. Fill out the args and press `<leader>r` to trigger the workflow
![image](https://github.com/user-attachments/assets/b988df90-df39-4748-b3bf-e3a315840d30)

## Requirements
This functionality relies on [gh-cli](https://cli.github.com/) so make sure you have it installed

## Contributions
While I initially developed this plugin to fulfill my own needs, I'm open to contributions and suggestions from the community. If you have any ideas or enhancements in mind, feel free to create an issue and let's discuss how we can make gh-actions.nvim even better!

