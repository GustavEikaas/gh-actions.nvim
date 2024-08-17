# gh-actions.nvim

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

![image](https://github.com/user-attachments/assets/e67b791f-ebae-4191-a840-ef477db6b2f4)

### Run
Trigger workflow_dispatch events directly from neovim

1. :Actions run
2. <leader>r on your desired workflow
3. The yaml definition is shown in the left float, the arguments for triggering is showed in the right float.
4. Fill out the args and press <leader>r to trigger the workflow
![image](https://github.com/user-attachments/assets/09fc9a7e-bd3f-44b8-82a7-1d275e7ea1af)


## Requirements
This functionality relies on [gh-cli](https://cli.github.com/)

## Contributions
While I initially developed this plugin to fulfill my own needs, I'm open to contributions and suggestions from the community. If you have any ideas or enhancements in mind, feel free to create an issue and let's discuss how we can make gh-actions.nvim even better!
