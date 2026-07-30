# Claves públicas del equipo

Una clave **pública** por integrante, con el nombre de usuario que va a tener en el servidor:

```
deploy/team-keys/
├── luca.pub
├── agustin.pub
├── emma.pub
├── zahira.pub
├── gines.pub
└── santiago.pub
```

`scripts/bootstrap-server.sh` crea la cuenta a partir del nombre del archivo (`emma.pub` →
usuario `emma`, con `sudo`) y autoriza esa clave.

## Cómo generar la tuya

```bash
ssh-keygen -t ed25519 -C "tu-nombre@archivista"
cat ~/.ssh/id_ed25519.pub
```

Pegá **esa** línea (la que empieza con `ssh-ed25519`) en un archivo con tu nombre y abrí un PR.

## Esto se commitea, y está bien

Una clave pública no es un secreto: existe justamente para publicarse. Lo que **nunca** va al
repositorio es el archivo sin `.pub` (`id_ed25519`), que es la clave privada. Si alguna vez
subís una por error, no alcanza con borrarla en otro commit: hay que generar un par nuevo.
