<p align="center">
  <img src="gif.gif">
</p>

# Flaggr!

A multiplayer team-based capture the flag version of the classic "Frogger" game, with bombing! This game was [made for Castle](https://castle.games/@nikki/flaggr).

The game's code is also intended to be an example for how to make a multiplayer game for Castle, so feel free to browse around! A description of the files involved:

- [**server.lua**](server.lua) -- The server-side code for the game (runs "in the cloud"). Maintains game state, performs gameplay logic and listens for when players enter and leave.
- [**client.lua**](client.lua) -- The client-side code for the game (runs on each player's computer). Receives state from the server, listens for input from the user and draws graphics for the current state of the game to the screen.
- [**common.lua**](common.lua) -- Imports '[share.lua](https://github.com/castle-games/share.lua)' and contains constants and logic that are common across both the server and the client.
- [**main_local.lua**](main_local.lua) -- The starting point to launch the game in 'local server' mode -- the server runs on your computer. Useful for quick testing while developing.
- [**main_castle.lua**](main_castle.lua) -- The starting point to launch the game in 'Castle server' mode -- Castle runs the game's server code in the cloud, which lets anyone connect and play. This is the file used when you find and launch 'Flaggr!' in Castle.