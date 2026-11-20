# Mapeamento da biblioteca

## Revisão ampliada — 24/10/2026

Total atual: **390 entradas, 455 poses/sequências e 4.725 quadros**. Conferidas as ações rotuladas de Nappa, Piccolo, Raditz, Gohan, Vegeta, Freeza e Rock Throwing Dino; incluído Grabbing Raditz do Goku. Gohan e Vegeta foram separados por roupa/forma. Acrescentados ciclos de locomoção de 92 variantes de inimigos cujas grades foram conferidas. Não foram inventados espelhamentos nem tempos originais.

Revisão visual adicional: 30 sequências em oito variantes de Ladybug, Phantom e Laser Turret. Ladybug: movimento, fechamento e descida da carapaça (esta apenas nas duas vistas laterais). Phantom/Poltergeist/Ghost: flutuação, braços elevados, giro de perfil, alongamento e materialização (esta apenas frontal). Laser Turret/Atomizer: abertura, pulsação e recuo do canhão. Os nomes descrevem o movimento visível; gatilhos, repetição e duração no jogo não foram confirmados. Seleções explícitas por coluna em `tools/review_gba_enemy_sequences.py`, persistidas em `gba_character_splits.json`; nenhuma regra foi extrapolada para outras folhas. Auditoria estrutural, igualdade dos 390 recortes e teste Godot das 455 poses passaram.

Auditoria: nenhum quadro vazio, fora da imagem ou com numeração inconsistente; igualdade pixel a pixel dos recortes e exportação Godot verificadas. O relatório `generated/sprites/characters/POSE_AUDIT.json` mantém `semantic_review_complete: false`: cobertura geométrica integral não confirma todas as ações ainda pendentes. As contagens seguintes são históricas.

## Verificação — 24/10/2026

Conferida visualmente a pose `angry` do Goku de Legacy of Goku: há quatro quadros frontais, não cinco. Removido o quinto recorte vazio. A auditoria cobre 256 sequências e 2.160 quadros; valida limites, conteúdo não vazio e numeração por direção. As três sequências adicionais do Spiky Armadillo seguem os rótulos WALK, ATTACK e DAMAGE da fonte. Esses testes não confirmam o significado de regiões ainda pendentes. Relatório: `generated/sprites/characters/POSE_AUDIT.json`.

## Lote restante de separação

Concluído o lote de 28 folhas coletivas/variantes restantes identificado na inspeção: 82 recortes, incluindo formas de Freeza, Dr. Gero com/sem chapéu, Gohan Kai com/sem espada e variantes de inimigos. Total atualizado: **385 entradas, 173 fontes, 253 sequências verificadas**. 141 entradas usam células de grade conferidas em vez de fragmentos conectados. Os demais recortes continuam candidatos a revisão. Este total não afirma que todas as ações foram semanticamente identificadas.

## Novo lote: inimigos e variantes

Separadas 27 variantes de 8 folhas: Fighters, Majin Soldier, Kuma Mercenary, Scorpion, Mummy, Skeleton, Ninja e Wolf. Os títulos presentes nas fontes foram preservados; variantes sem nome recebem a cor como identificação provisória. Acrescentadas 27 poses de repouso em quatro direções. Total: 331 entradas GBA e 184 sequências verificadas; demais ações continuam pendentes.

## Cobertura integral das fontes, poses ainda parciais

O gerador agora inclui **todas as 173 folhas GBA** do inventário, em **312 entradas**. Antes, 109 folhas sem sequências aprovadas não apareciam na oficina. Agora cada entrada oferece três modos: poses revisadas, quadros pendentes e folha completa. Os retângulos dos candidatos são convertidos para o recorte do personagem, preservando a origem; interseções com limites de personagens são sinalizadas nos JSONs.

Há **157 sequências GBA revisadas** no gerador. Foram acrescentadas sete de Goku em Buu's Fury: corrida, ataque com braços estendidos, desaparecimento, ataque com mãos juntas, voo horizontal, voo diagonal e queda lateral. Coordenadas persistem em `tools/sprite_generator/gba_reviewed_extended.json`. São descrições visuais; não determinam a habilidade, comando ou duração no jogo original.

O relatório `generated/sprites/characters/POSE_COVERAGE.md` lista as pendências por entrada. **27.936 regiões pendentes não equivalem a 27.936 poses**: há texto, fragmentos e possíveis recortes incompletos. A identificação semântica de todas as ações ainda não foi concluída. No modo pendente, exporta-se apenas o recorte selecionado, explicitamente marcado como não revisado.

Validações: presença de todas as fontes, hashes originais, igualdade pixel a pixel dos recortes e candidatos, teste Godot de todas as sequências, alternância entre modos e exportação de recorte pendente. As contagens abaixo são o histórico das entregas anteriores.

## Poses no gerador e tela de escolha

A oficina Godot agora abre sem selecionar automaticamente o Goku, com busca e filtro GBA/HU2. O catálogo do gerador reúne **203 entradas GBA**, com **150 sequências disponíveis em 53 entradas**: 133 revisadas anteriormente mais 17 poses de NPCs separadas nesta etapa. As demais entradas continuam como blocos estáticos identificados para revisão.

As poses novas estão registradas em `gba_character_splits.json`, com retângulos na folha original. `split_gba_characters.py` converte essas coordenadas para os recortes e também incorpora as 43 folhas individuais que já tinham poses revisadas. Os JSONs exportados guardam coordenadas de origem e do recorte; quadros fora do personagem causam erro. Não foram inferidos tempos originais: a prévia GBA usa 7 fps.

Validação Godot: todas as 150 sequências comparadas pixel a pixel com os recortes, busca/filtro, ausência de seleção inicial, recoloração, exportação PNG/SpriteFrames e regressão HU2. Veja [SPRITE_GENERATOR.md](SPRITE_GENERATOR.md) para executar e selecionar personagens. Os números das seções seguintes são históricos.

## Separação das folhas coletivas GBA — 21/10/2026

Foram conferidas visualmente **21 folhas coletivas**, gerando **160 recortes**: personagens, variantes de NPCs e alguns efeitos separados. Exemplos: Força Ginyu, famílias de Bulma e Goku, Casa Kame, Templo de Kami, Kaios, King Cold/Mecha Frieza, soldados de Freeza e folhas de NPCs genéricos dos três jogos.

Abra **`generated/sprites/characters/index.html`**, também acessível pelo link no topo do catálogo. Cada cartão oferece PNG, JSON com coordenadas, fonte original/créditos e retorno ao catálogo. No Obsidian, abra **Personagens GBA** pelo índice **Início**.

Os recortes preservam os pixels e o fundo originais, sem redimensionamento. Personagens distribuídos em vários blocos, como King Yemma, recebem um atlas com os blocos empilhados e coordenadas de origem/destino no JSON. Os arquivos originais permanecem intactos. Transformar esses blocos em animações e remover o fundo são etapas distintas, ainda não realizadas aqui.

Nomes de NPCs sem identificação segura permanecem genéricos/provisórios. Estes 160 arquivos não representam 160 identidades canônicas únicas: há variantes, repetições entre jogos e efeitos. A separação cobre as 21 folhas registradas em `tools/sprite_generator/gba_character_splits.json`; não afirma que todas as demais folhas sejam de um único personagem.

```powershell
# Gera novamente os recortes a partir das coordenadas revisadas:
python tools/split_gba_characters.py
# Verifica hash das fontes e igualdade pixel a pixel de todos os blocos:
python tools/test_gba_character_splits.py
```

O comando de atualização geral do catálogo também regenera os recortes. As receitas e o script são reproduzíveis; as imagens derivadas permanecem na pasta local ignorada `generated/sprites/characters`. Testes de pixels, catálogo existente e galeria no Edge passaram.

## Catálogo preliminar completo — 21/10/2026

Todas as **344 fontes do inventário** agora têm ficha e navegação no catálogo:

| Origem | Cobertura |
| --- | --- |
| HU2 | 171 DMI, 3.276 estados e 29.816 quadros direcionais declarados na fonte |
| GBA | 173 folhas, 30.183 regiões candidatas organizadas em 2.254 grupos espaciais |
| Revisão GBA anterior | 133 sequências visualmente confirmadas, preservadas |
| Alertas GBA | 6.446 regiões com tamanho/proporção suspeitos |

Isso completa a **organização preliminar do inventário**, não a identificação semântica de todas as poses. Uma folha pode conter vários personagens. Linhas automáticas podem misturar ações, partes soltas e texto; regiões menores que o limiar do detector podem estar ausentes. Confira a folha inteira durante a curadoria. Ausência de alerta não confirma qualidade. Os números dos lotes abaixo são históricos.

Abra `generated/sprites/catalog/index.html` no navegador. Filtre personagem/jogo, origem, nome da ação e grupos confirmados/provisórios/com alertas. As miniaturas selecionam recortes; a prévia anima apenas sequências com direção conhecida. Grupos automáticos ficam separados de `poses`, sem alimentar o gerador do jogo como poses aprovadas.

Em **Decisão sobre o grupo selecionado**, informe personagem, ação, observações e aprovação/correção/descarte. Clique em **Salvar decisão local**, depois em **Exportar curadoria JSON** para guardar uma cópia. O salvamento fica neste navegador; o JSON permite recuperar as decisões e entregá-las para a revisão. A importação confere fonte, hash, identificador e retângulos. Aprovações são registros humanos e não promovem automaticamente grupos para o jogo.

Para Obsidian, veja [OBSIDIAN.md](OBSIDIAN.md). Foram geradas 344 fichas, um índice e uma área de notas preservada nas atualizações.

```powershell
# Reaplica revisões e gera catálogo/cofre usando inventário com fontes verificadas:
python tools/map_sprite_library.py --refresh-reviews
# Reescaneia fontes quando adicionar/remover folhas:
python tools/map_sprite_library.py
# Confere limites, cobertura dos candidatos, determinismo e preservação das notas:
python tools/test_sprite_mapping.py
```

Validação desta entrega: todas as regiões candidatas pertencem exatamente a um grupo; nenhum recorte ultrapassa a fonte; fontes locais verificadas por hash. Teste real em Edge headless passou para filtros, animação, resultado vazio, persistência e exportação/importação JSON, sem erros JavaScript. O manifesto GitHub usado continua sendo o commit `68124171efe28d9e7129d6a1392c15fdcc6257ed`; não representa uma consulta nova à ponta da branch.

Implementação: `tools/sprite_mapping_workspace.py` e `tools/sprite_generator/catalog.html`. Arquivos gerados ficam na pasta ignorada `generated/sprites/`. Não houve publicação no GitHub nem alteração das imagens originais nesta entrega.

## Terceiro lote — 21/10/2026: combate

Total atualizado: **133 sequências GBA confirmadas**. Acrescentadas 28 sequências, 448 quadros direcionais, após inspeção ampliada com colunas numeradas. Fonte persistente: `tools/sprite_generator/gba_reviewed_combat.json`.

- Buu's Fury: Goku, Vegeta, Goten, Trunks, Gohan (School), Videl e Hercule.
- Legacy of Goku II: Future Trunks, Vegeta, Piccolo e Piccolo sem pesos.

Os nomes `punch_a`/`punch_b` distinguem blocos visuais de socos; não afirmam a ordem dos combos no jogo. Videl usa `melee_a`/`melee_b`/`melee_c` para sequências de combate cuja classificação mais específica continua pendente. Chutes reconhecidos foram registrados como `kick`. Não se copiou uma regra universal de colunas: por exemplo, Vegeta de Buu's Fury tem chute nas colunas 14–17, enquanto Vegeta de Legacy of Goku II tem outro bloco de soco nesse intervalo e chute em 18–21.

Validação: hash da fonte, retângulos dentro da imagem, quatro direções e ausência de recortes vazios. Não foram alterados sprites originais nem o combate do jogo. Tempos, pontos de apoio, demais ataques e folhas restantes ainda precisam de revisão.

Para reproduzir a inspeção ampliada no Godot:

```powershell
# Após --: caminho da folha, primeira coluna e quantidade de colunas.
godot --path . --script tools/preview_gba_columns.gd -- 'caminho/folha.png' 10 12
```

O utilitário salva `audit-gba-columns.png`, com quatro linhas de direções e rótulos de coluna. O comando usa a grade de 32 × 32 com cabeçalho de 32 pixels dessas folhas; não serve automaticamente para a disposição irregular de Legacy of Goku 1.

## Segundo lote: movimento dos jogáveis

Revisadas visualmente as 42 folhas em `Playable Characters` de Buu's Fury (24) e Legacy of Goku II (18). Foram acrescentadas 86 sequências de repouso/caminhada, com as quatro direções, em `tools/sprite_generator/gba_reviewed_movement.json`. O Gohan com roupa de Kai tem blocos separados com e sem espada. Nas demais folhas, o repouso usa a coluna 0 e a caminhada as colunas 2–5 da grade de 32 pixels, após o cabeçalho de 32 pixels. Essas coordenadas foram conferidas nas folhas deste lote; não constituem regra para qualquer sprite GBA.

Total atual: **105 sequências GBA confirmadas**. A revisão segue parcial: esse lote não confirma todos os golpes, transformações, NPCs ou inimigos. As contagens menores abaixo são o histórico dos lotes anteriores.

O catálogo agora oferece **Animar direção selecionada** e uma prévia ampliada do recorte. Para GBA, usa 7 quadros/s apenas para inspeção, sem alegar o tempo original do jogo. No HU2, usa os tempos declarados nos DMI. Selecione `walk` e uma direção para ver a sequência; o botão novamente interrompe a reprodução. Regiões candidatas não são animadas como se fossem poses confirmadas.

Verificação: hashes das fontes, limites dos retângulos, quatro direções por sequência e ausência de quadros vazios nas 42 folhas. As imagens originais permanecem intactas.

## Revisão visual e tentativa com REA

REA 6.5.0 foi executado nesta revisão:

- `rea inspect-artifact assets/sprites/characters/goku/hu2/Goku.dmi --format json`: `target_unavailable`, `file_format_rejected`, formato binário não suportado.
- O mesmo comando no PNG `assets/sprites/characters/goku/source/goku_buus_fury_source.png`: mesma rejeição.
- `rea observe-native-ui references/roms/visualboyadvance-m.exe --pid 24328 --window-id 135010 --format json`: `capability_unavailable`; as utilidades nativas desse provedor exigem macOS. PID e janela correspondem à sessão desta revisão, não devem ser reutilizados sem conferência.

Portanto, o REA não identificou poses nesta sessão. Sua ajuda ficou limitada à verificação de capacidades; os resultados abaixo provêm da inspeção visual e dos rótulos das folhas.

Primeiro lote: 18 sequências do Goku de Legacy of Goku 1 registradas em `tools/sprite_generator/gba_reviewed_poses.json`: idle, caminhada, soco, carga, disparo, voo, derrota, carregar/caminhar/balançar/voar com martelo, ações de martelo não usadas, empolgação, tristeza, raiva, braços erguidos, tédio e transformação. A folha rotula frente, costas e lateral; a lateral permanece `side`, sem inventar quadros espelhados. Tempos e pontos de apoio ainda não foram medidos. Grabbing Raditz e efeitos separados dessa folha continuam pendentes.

O catálogo agora contém **19 sequências GBA confirmadas** (18 deste lote e a Spirit Bomb de Buu's Fury). Isso ainda não conclui a revisão das 173 folhas. Coordenadas ficam vinculadas ao SHA-256 da fonte; o atualizador recusa fontes alteradas e retângulos fora da imagem.

Atualizar a página aberta após uma revisão:

```powershell
python tools/map_sprite_library.py --refresh-reviews
```

Recarregue `index.html` no navegador e selecione `Goku__39935`; as sequências revisadas aparecem antes das regiões candidatas.

Abra `generated/sprites/catalog/index.html` no navegador. Filtre por personagem ou jogo, escolha estado e direção/quadro: o retângulo vermelho identifica a região na imagem original. A opção de zoom não altera os arquivos.

## Cobertura efetivamente verificada

| Fonte | Cobertura | Resultado |
| --- | --- | --- |
| HU2 | 171 DMI em `Icons/Characters` | 3.276 estados e 29.816 quadros direcionais, coordenadas e tempos extraídos dos metadados |
| GBA | 173 folhas de jogáveis, NPCs, inimigos, protótipos e conteúdo não usado dos três jogos | Inventário completo dessas categorias; 30.183 regiões candidatas, ainda sem identificação semântica completa |
| GBA / Goku de Buu's Fury | Spirit Bomb | Uma pose confirmada visualmente, nas quatro direções |

**O pedido de mapear todas as poses GBA ainda não está concluído.** Não interpretar contagem de regiões como contagem de poses nem de personagens: há folhas com vários personagens, texto e partes desconectadas. Estados DMI decorativos também são preservados; um nome de estado não garante que seja uma ação utilizável no jogo.

Os 171 arquivos locais foram comparados por Git blob SHA-1 com `kikajima/dragonballsoullegacy`, branch `develop`, commit `68124171efe28d9e7129d6a1392c15fdcc6257ed`. Também correspondem ao diretório original de `DarkerLegends/HeroesUnited2`, commit `1768d9cab18631f4009a86ef35027ece9158aac3`. Nenhuma divergência encontrada.

## Dados

- `catalog.json`: fontes, dimensões, hashes, estados, direções, tempos, coordenadas e status de confirmação.
- `summary.json`: contagens, divergências e erros.
- `index.html`: inspeção local das fontes sem modificar imagens.

Estados repetidos recebem identificadores estáveis, como `fly#0` e `fly#1`. Seus atributos `movement`, `rewind` e `loop` são registrados como definidos na fonte, sem descartar variantes. A oficina de sprites passa a exibir essas variantes quando o catálogo existe. O leitor usado pelo jogo continua com seu comportamento anterior.

Nos GBA, a detecção por componentes conectados é somente auxílio de inspeção. Não identifica automaticamente corrida, ataque ou direção; não corrige alinhamento nem separa personagens com segurança. O catálogo não inclui os jogos não Dragon Ball que também existem na pasta fornecida.

## Reproduzir

```powershell
python tools/map_sprite_library.py
```

Requer Pillow no Python (já disponível no ambiente verificado). O comando lê as fontes, grava apenas em `generated/sprites/catalog/` e usa `tools/sprite_generator/github_manifest.json` como fotografia do inventário remoto. Para outro computador:

```powershell
python tools/map_sprite_library.py --gba-root 'C:\caminho\game_boy_advance'
```

A próxima etapa é validar visualmente os agrupamentos e nomear ações das folhas GBA, registrando retângulos, direção, sequência, duração e posição dos pés. Os tempos das folhas PNG não estão presentes na imagem e precisam de observação do jogo ou escolha explícita para o projeto.
