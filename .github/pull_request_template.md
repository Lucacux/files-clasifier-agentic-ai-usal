## Qué hace

<!-- Descripción corta y concreta. Si el issue ya lo explica, alcanza con una o dos líneas. -->

Closes #

## Por qué así

<!-- Decisiones no obvias que tomaste. Si descartaste una alternativa razonable, decilo acá.
     Si la decisión es grande, va ADR en docs/adr/ y lo enlazás. -->

## Cómo lo probaste

<!-- Comandos, escenarios, casos borde. "Corrí los tests" no alcanza: decí qué probaste
     que antes fallaba y ahora no. -->

```bash

```

## Checklist

- [ ] El PR está enlazado a un issue (`Closes #N`)
- [ ] `make check` pasa en local (lint + tipos + tests)
- [ ] Hay tests del camino feliz **y** de al menos un caso de error
- [ ] La documentación afectada está actualizada en este mismo PR
- [ ] Si cierra un requisito de la consigna: actualicé `docs/08-mapeo-requisitos.md`
- [ ] Si tomé una decisión de arquitectura: hay un ADR en `docs/adr/`
- [ ] No agregué secretos, tokens ni rutas personales
- [ ] No agregué borrados automáticos de archivos (ver [ADR-0005](../docs/adr/0005-borrado-con-aprobacion-humana.md))

## Notas para quien revisa

<!-- ¿Hay algo que quieras que miren con particular atención? ¿Algo que dejaste a propósito
     para otro PR? Decilo acá. -->
