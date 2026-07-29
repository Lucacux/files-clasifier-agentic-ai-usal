"""Tests for the CLI contract.

These lock down the argument surface that the rest of the project develops
against, so an accidental rename of a subcommand fails CI instead of breaking
the demo script.
"""

from __future__ import annotations

import pytest

from archivista import __version__
from archivista.cli import build_parser, main

EXPECTED_COMMANDS = {
    "run",
    "status",
    "pending",
    "reload",
    "pause",
    "resume",
    "approve",
    "reject",
    "undo",
    "scan",
}


def _subcommands() -> set[str]:
    parser = build_parser()
    actions = [a for a in parser._actions if a.dest == "command"]  # noqa: SLF001
    assert actions, "el parser debe exponer subcomandos"
    return set(actions[0].choices or {})


def test_version_is_set() -> None:
    assert __version__


def test_all_documented_commands_exist() -> None:
    assert _subcommands() == EXPECTED_COMMANDS


def test_no_command_prints_help_and_fails() -> None:
    assert main([]) == 1


def test_unknown_command_is_rejected() -> None:
    with pytest.raises(SystemExit):
        main(["comando-inexistente"])


@pytest.mark.parametrize("command", sorted(EXPECTED_COMMANDS - {"approve", "reject", "undo"}))
def test_known_commands_parse(command: str) -> None:
    # Todavía no implementados: deben salir con 2, no reventar.
    assert main([command]) == 2


@pytest.mark.parametrize("command", ["approve", "reject", "undo"])
def test_commands_requiring_an_id(command: str) -> None:
    assert main([command, "7"]) == 2
    with pytest.raises(SystemExit):
        main([command])
