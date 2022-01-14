+ Feel free to raise issues or create pull requests.
+ If you make a frontend, let me know or edit the readme with a link to your project.

### Guidelines
+ Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0-beta.2/#summary)
+ Update documentation if applicable

### Testing
+ Run `make test` to test (and make sure that you add tests if create new functionality)
+ I've been unable to get good integration tests going, but unit tests good. If anyone _can_ get integration tests up and running that would be great.
    + My main problems have been with `nvim_feedkeys` not working as expected for abbreviations when under plenary, and with `vim.api.nvim_buf_attach#on_bytes` not working correctly either under plenary
