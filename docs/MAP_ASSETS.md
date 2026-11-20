# Sprites aplicados aos mapas

Esta revisão reaproveita HU2 e Legacy of Goku II disponíveis localmente. A integração fica em `world/existing_asset_scenery.gd`, chamada quando o mapa carrega. Montagens usam pixels nativos, filtro nearest e profundidade pelo pé do objeto.

| Mapa | Recursos aplicados |
| --- | --- |
| Casa do Kame | Cama, TV, geladeira, mesas, sofá, estante, livros, tapete e planta de `Furniture__232446.png` |
| Ilha | Cadeira de praia da mesma folha, sem o fragmento do guarda-sol vizinho |
| West City | Fachadas modulares `RectBuilding.dmi` e `SquareBuilding.dmi`; bancos, canteiros e faixas `CityTurfs.dmi`; árvore `FancyTree.png`; placa GBA |
| Sala de treino | `GravMachine.png`, terminais e cápsula de recuperação GBA, pisos e paredes HU2, estados `PunchingBag` e `PunchingBagHit` de `Other.dmi` |
| Rocky Wastes | Solo recortado de `Northern Wastelands__159968.png`, `RockSlide.png` e pequenas pedras de `Flowers.dmi` |

As cores planas de água presentes no RockSlide são descartadas pelo shader `rock_slide_land.gdshader`, para as pedras assentarem no solo. As demais cores são preservadas.

Ampliação de 31/10/2026: os checkpoints usam os quatro quadrantes `PortalTL/TR/BL/BR` de CityTurfs, acima do terreno e abaixo dos atores. A cadeira, o guarda-sol e o marcador da ilha foram reposicionados para ficarem em terra. A construção adicional da cidade tem base física; sua porta é decorativa, sem um novo interior.

Colisões de cama e mesa acompanham os sprites selecionados; sofá, mesa de centro e bancos receberam bases físicas. Interações de descanso, geladeira, TV, consoles e portais continuam nos mesmos nós. A montagem é idempotente para não duplicar objetos ao reaplicar detalhes.

## Reproduzir os recortes GBA

Os PNGs derivados ficam locais em `assets/sprites/environment/gba_furniture/`, ignorados pelo Git conforme a convenção do projeto. Execute:

```powershell
python tools/extract_environment_sprites.py
```

Em outro computador, informe os caminhos com `--source` (Furniture) e `--terrain-source` (Northern Wastelands). O script grava hashes, créditos, coordenadas e exclusões em `sources.json` e `terrain_source.json`. A remoção do fundo dos móveis usa somente as duas cores exatas do quadriculado. Abra o Godot para importar os PNGs. Se faltarem recortes locais, os objetos anteriores continuam disponíveis.

## Verificação

`tools/test_environment_assets.gd` verifica os cinco mapas, 146 sprites da biblioteca, ausência de duplicação, texturas, escala, bases físicas, interações, cadeira dentro da costa e animação do saco de treino. Executado sem `--headless`, gera `audit-library-<mapa>.png` e detalhes da cidade/sala de treino. Os testes usam save descartável desde a inicialização, incluindo os autosaves de checkpoints. `tools/audit_gameplay.gd` cobre colisões, portais, combate e save/load.

Ainda existem elementos provisórios, como a esteira e alguns limites do cenário. Esta etapa não afirma que toda a biblioteca foi utilizada.
