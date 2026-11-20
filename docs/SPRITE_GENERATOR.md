# Oficina de sprites

**Abertura direta:** dê dois cliques em `ABRIR_GERADOR.cmd`, na raiz do projeto. Esse atalho executa a cena da oficina independentemente da aba aberta no Godot. A janela se chama **Oficina de sprites — catálogo HU2 / GBA**.

Se o F6 mostrar apenas Goku num fundo cinza, confira a aba de cena do Godot: `actors/player/player.tscn` executa somente o jogador. Abrir o catálogo HTML no VS Code não troca a cena atual do Godot. Para usar F6, abra a cena da oficina no painel **Sistema de arquivos** do Godot e selecione sua aba.

Abra `tools/sprite_generator/sprite_generator.tscn` no Godot e pressione **F6** para executar essa cena. **F5** abre o jogo. A oficina agora abre sem personagem selecionado; não carrega mais o Goku automaticamente.

## Escolher e animar

1. Digite um nome na busca e, se desejar, filtre **GBA** ou **HU2**.
2. Abra a lista **Escolha um personagem** e selecione a fonte.
3. Escolha a pose e a direção. Por exemplo: `Roshi` → `GBA — Master Roshi [dbzlog2]` → `walk` → `Esquerda`.
4. Escolha uma cor original e sua substituta; clique em **Trocar cor em todas as poses**. **Restaurar cores originais** desfaz as trocas.
5. Clique em **Exportar PNG + SpriteFrames + receita**.

## Cobertura atual

- 171 arquivos HU2: animações, direções e tempos declarados nos DMI, incluindo estados duplicados como `fly#0` e `fly#1`.
- 390 entradas GBA, cobrindo todas as 173 folhas do inventário: personagens/variantes/efeitos separados e fontes ainda não separadas.
- **455 sequências GBA verificadas**, com as variantes restantes de inimigos e formas separadas. O mapeamento continua parcial por personagem; nomes descritivos não confirmam gatilhos ou tempos originais do jogo.
- Os NPCs novos incluem Mestre Kame, Launch, Kami, Dende, Mr. Popo, Korin, Yamcha, Puar e Oolong, além de Chiaotzu na folha de amigos de Goku. Alguns têm somente repouso; os ciclos de movimento foram registrados onde conferidos visualmente.
- O seletor de visualização oferece **Poses revisadas**, **Quadros pendentes de revisão** e **Folha completa / blocos**. Fontes sem poses verificadas abrem nos recortes pendentes. Estes são estáticos e podem incluir texto ou fragmentos; não são animações confirmadas. A folha completa continua acessível mesmo quando existem poses revisadas.

GBA usa **7 fps ilustrativos**, pois a duração original não foi medida. `side` em Legacy of Goku 1 continua sendo uma direção lateral única, sem espelhamento inventado. As imagens GBA mantêm o fundo original; não há remoção automática do fundo nesta etapa.

## Exportação

Os resultados vão para uma pasta nova em `generated/sprites/`:

- `spritesheet.png`: atlas com os pixels originais ou recoloridos; 16 colunas para HU2, uma coluna para GBA.
- `animations.tres`: SpriteFrames com imagens incorporadas, que pode ser atribuído a AnimatedSprite2D.
- `recipe.json`: fonte, hash GBA, coordenadas, poses, cores e tempos usados na prévia.

A prévia usa escala inteira quando amplia e ajusta blocos grandes à área disponível. O PNG exportado preserva a resolução. A recoloração é global: cabelo e roupa mudam juntos se compartilham a mesma cor. Não há criação de poses novas, camadas automáticas, reabertura de receitas nem integração automática no jogador.

## Atualizar e verificar

```powershell
python tools/map_sprite_library.py --refresh-reviews
python tools/test_gba_character_splits.py
```

No primeiro inventário, ou ao adicionar/remover folhas, execute `python tools/map_sprite_library.py` sem a opção de cache. Os arquivos gerados ficam ignorados pelo Git; preserve as notas manuais antes de apagar a pasta.

`tools/test_sprite_generator.gd` verifica HU2/GBA, recoloração, exportação e reabertura dos arquivos. `tools/test_gba_generator_poses.gd` verifica a abertura sem seleção, busca/filtro, todos os quadros das sequências GBA e exportação de animações. As fontes originais permanecem intactas. A oficina é uma ferramenta local de desenvolvimento, não um aplicativo Godot exportado.

## Pendências explícitas

O mapeamento semântico de todas as poses **ainda não está concluído**. O gerador anteriormente omitia 109 fontes e escondia o restante dos quadros nas folhas parcialmente revisadas; essa restrição foi removida. O relatório `generated/sprites/characters/POSE_COVERAGE.md` lista poses verificadas e regiões pendentes para cada entrada. Regiões são candidatos geométricos e sua contagem não equivale ao número de poses faltantes.

No modo de quadros pendentes, a exportação grava somente o recorte selecionado, com status de revisão na receita. Nos demais modos, exporta o conjunto exibido. Selecionar uma região não a aprova automaticamente.

## Recortes completos do lote restante

Foram separadas 82 entradas de 28 folhas adicionais, incluindo variantes de inimigos, formas de Freeza, Dr. Gero com/sem chapéu e Gohan Kai com/sem espada. O total é de 385 entradas cobrindo 173 fontes. Há 57 receitas de separação; as demais fontes permanecem como entradas individuais.

141 entradas usam grades conferidas: seus quadros pendentes preservam mãos, efeitos e outras partes desconectadas dentro da célula. As folhas irregulares continuam usando regiões candidatas, sem garantia de segmentação perfeita. Todas as ações ainda não identificadas permanecem pendentes; a organização dos recortes não equivale a confirmar todas as animações.
