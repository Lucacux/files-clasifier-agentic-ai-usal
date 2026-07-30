"""Command line entry point.

This is the walking skeleton: the argument surface is fixed here so every other
module can be developed against a stable CLI contract. The subcommands are
implemented as part of the daemon/IPC work.

See docs/01-arquitectura.md section 2.9 for the full command reference.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence

from archivista import __version__

_NOT_IMPLEMENTED_HINT = (
    "El comando '{cmd}' todavía no está implementado. "
    "Seguí el avance en los issues del repositorio."
)


def build_parser() -> argparse.ArgumentParser:
    """Build the top level argument parser."""
    parser = argparse.ArgumentParser(
        prog="archivista",
        description="Organizador inteligente de archivos basado en eventos del sistema.",
    )
    parser.add_argument("--version", action="version", version=f"archivista {__version__}")
    parser.add_argument(
        "--config",
        metavar="RUTA",
        default="/etc/archivista/archivista.yaml",
        help="Ruta del archivo de configuración.",
    )

    sub = parser.add_subparsers(dest="command", metavar="COMANDO")

    run = sub.add_parser("run", help="Ejecuta el daemon.")
    run.add_argument(
        "--foreground",
        action="store_true",
        help="No se separa de la terminal (útil para depurar y para systemd).",
    )

    sub.add_parser("status", help="Estado del daemon, la cola y el modelo.")
    sub.add_parser("pending", help="Lista las operaciones que esperan aprobación.")
    sub.add_parser("reload", help="Recarga la configuración sin reiniciar.")
    sub.add_parser("pause", help="Suspende el consumo de la cola.")
    sub.add_parser("resume", help="Reanuda el consumo de la cola.")

    approve = sub.add_parser("approve", help="Aprueba una operación pendiente.")
    approve.add_argument("id", help="Identificador de la operación.")

    reject = sub.add_parser("reject", help="Rechaza una operación pendiente.")
    reject.add_argument("id", help="Identificador de la operación.")

    undo = sub.add_parser("undo", help="Revierte una operación del log de auditoría.")
    undo.add_argument("id", help="Identificador de la operación.")

    scan = sub.add_parser("scan", help="Fuerza un reindexado.")
    scan.add_argument("path", nargs="?", help="Carpeta a reindexar.")
    scan.add_argument("--all", action="store_true", help="Reindexa todas las observadas.")

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """Run the CLI. Returns the process exit code."""
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help()
        return 1

    print(_NOT_IMPLEMENTED_HINT.format(cmd=args.command), file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
