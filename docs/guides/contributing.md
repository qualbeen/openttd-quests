# Contributing to OpenTTD Quests

## Ways to Contribute

### Propose a Quest
Open a [Quest Proposal issue](https://github.com/qualbeen/openttd-quests/issues/new?template=quest-proposal.md) describing your idea. Include objectives, rewards, and where it fits in the progression tree.

### Write a Quest
1. Fork the repository
2. Create a YAML file in `quests/progression/` or `quests/side-quests/`
3. Follow the format in [quest-writing.md](quest-writing.md)
4. Open a pull request

### Report Balance Issues
If a quest feels too easy, too hard, or the reward doesn't fit, open a [Balance Feedback issue](https://github.com/qualbeen/openttd-quests/issues/new?template=balance-feedback.md).

### Improve the GameScript
Code contributions to the Squirrel GameScript in `gamescript/` are welcome. Test your changes in-game before submitting a PR.

## Development Setup

1. Clone the repo
2. Symlink or copy `gamescript/` to your OpenTTD `game/` directory
3. Start a new game with the script enabled
4. Use OpenTTD's AI/GS debug window for logging

## Code Style

- Squirrel files use 4-space indentation
- Function names are PascalCase
- Local variables are snake_case
- Constants are ALL_CAPS
