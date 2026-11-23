rockspec_format = "3.0"
package = "questchain-dev"
version = "scm-1"
source = { url = "git+https://github.com/damoninc/wow-forever-questchain.git" }
description = { summary = "Development tools for the QuestChain WoW addon" }
dependencies = {
    "lua >= 5.1, < 5.2",
    "luacheck == 1.2.0-1",
}
build = { type = "builtin", modules = {} }
