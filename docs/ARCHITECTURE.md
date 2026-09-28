# Arquitetura

O projeto é organizado para manter lógica, dados, apresentação e rede desacoplados.

## Player atual

```text
Player
├── Visuals
│   ├── AnimatedSprite2D
│   ├── ChargeAura
│   └── AnimationController
├── CollisionShape2D
├── Combat
│   └── AttackHitbox
├── Components
│   ├── MovementComponent
│   ├── FacingComponent
│   ├── StateMachine
│   ├── MeleeCombatComponent
│   ├── HitStopComponent
│   ├── HealthComponent
│   ├── KnockbackComponent
│   ├── GuardComponent
│   ├── KiComponent
│   ├── KiBlastComponent
│   ├── ExperienceComponent
│   └── LevelStatsComponent
├── Hurtbox
├── Controllers
│   └── PlayerInputController
└── Camera2D
```

Estados atuais do jogador:

```text
idle
walk
run
attack_1
attack_2
kick_1
kick_2
hurt
block
ki_blast
charge_ki
```

## Locomoção

A locomoção do jogador possui três estados básicos:

```text
idle → sem movimento
walk → direção pressionada
run  → direção + Espaço
```

O action interno `dash`, que já estava mapeado para Espaço, é usado temporariamente como modificador de corrida contínua. A velocidade de corrida começa em 1,55× a velocidade normal e a animação usa quatro quadros por direção a 12 FPS.

O spritesheet local esperado é:

```text
assets/sprites/characters/goku/processed/goku_buus_fury_run.png
```

A corrida só é aplicada durante locomoção normal; ataque, defesa, dano, carregamento de Ki e disparos continuam obedecendo seus próprios estados e restrições.

## Combate físico

O `MeleeCombatComponent` concentra agora os ataques físicos e o buffer de combo. Soco e chute usam a mesma hitbox, mas possuem temporização, dano, alcance e variantes independentes.

**J** alterna:

```text
attack_1 → attack_2 → attack_1 → ...
```

**I** alterna:

```text
kick_1 → kick_2 → kick_1 → ...
```

Os quatro frames do sheet de chute são divididos em duas animações por direção:

```text
kick_1 = frames 0-1
kick_2 = frames 2-3
```

Isso representa as duas pernas e permite que cada pressionamento de I produza um chute distinto.

O buffer é compartilhado entre os tipos de golpe, portanto também é possível trocar de ataque no meio da sequência:

```text
J → I → J → I
J → J → I
I → I → J
```

A cadência agora diferencia ataques repetidos de trocas de tipo. Soco → soco e chute → chute continuam responsivos, enquanto soco → chute e chute → soco esperam um pouco mais da recuperação visual antes de trocar. O input buffer foi ampliado para preservar comandos feitos antecipadamente.

Janelas iniciais de encadeamento:

- soco → soco: 0,27 s;
- chute → chute: 0,34 s;
- soco → chute: 0,34 s;
- chute → soco: 0,40 s;
- input buffer: 0,30 s.

Os chutes também usam uma pose de recuperação (`0 → 1 → 0` e `2 → 3 → 2`) a 7 FPS para evitar uma troca visual brusca entre perna e soco.

Parâmetros iniciais:

- soco: 10 de dano, alcance de hitbox 12 px;
- chute: 16 de dano, alcance de hitbox 15 px;
- movimento durante soco: 85% da velocidade;
- movimento durante chute: 70% da velocidade.

A direção do golpe atual permanece estável durante sua janela ativa, enquanto a direção desejada do jogador continua sendo atualizada para o próximo golpe.

## Defesa

O `GuardComponent` mantém o estado de defesa separado da lógica do Player. A defesa verifica a direção do personagem e a posição de origem do golpe.

Golpes recebidos pela frente são reduzidos para 25% do dano original no protótipo. Golpes por trás ignoram a defesa. Um golpe bloqueado não coloca o jogador no estado `hurt` nem aplica knockback.

Enquanto o estado `block` está ativo, o personagem fica completamente imóvel. O input direcional continua alimentando o `FacingComponent`, permitindo apenas girar a guarda para `up`, `down`, `left` ou `right` sem deslocar o corpo.

## Ki e técnicas

`KiComponent` concentra o recurso de Ki e expõe consumo, recuperação e sinais de mudança.

O primeiro ataque de energia é o Ki Blast pequeno:

```text
K
↓
KiBlastComponent
├── verifica e consome Ki
├── executa a pose de disparo de 3 quadros
├── aceita novos toques em K no buffer
└── instancia um KiBlastProjectile por toque
        ↓
    Hurtbox inimiga
        ↓
    HealthComponent
```

A sequência foi ajustada a partir da referência em vídeo do jogo original. O primeiro disparo usa uma preparação curta de aproximadamente 0,22 s. Depois disso, os tiros podem continuar em intervalos de 0,40 s, alternando diretamente entre os dois braços sem retornar à pose neutra entre projéteis. Um toque em K ainda gera um único tiro; manter K pressionado mantém a rajada, e toques adicionais podem ser armazenados no buffer.

A animação usa três poses direcionais do spritesheet de Buu's Fury (colunas originais 28-30): `ki_blast_prepare`, `ki_blast_1` e `ki_blast_2`. As poses de braço são estáticas entre um disparo e outro, reproduzindo a fluidez observada no jogo. O projétil pequeno continua usando o spritesheet local de efeitos e sua velocidade base foi elevada para 300 px/s.

Ao segurar **L**, o Player entra em `charge_ki` e fica completamente parado. O carregamento usa os mesmos dois quadros frontais em qualquer direção: o primeiro quadro aparece no início e a animação avança uma única vez para o segundo, que permanece estático enquanto o Ki é recuperado. Ao atingir o Ki máximo, a aura é desligada e o segundo quadro não reinicia. Se o Ki já estiver cheio antes de pressionar L, o carregamento não começa.

Durante `ki_blast`, o Player também fica completamente parado até o término do cast. O deslocamento volta somente depois que a técnica termina.

## HUD

`CombatHUD` fica no `UIContainer` do bootstrap e observa os componentes, sem duplicar os valores de gameplay:

```text
HealthComponent ─────→ barra vermelha de HP
KiComponent ─────────→ barra verde de Ki
ExperienceComponent ─→ barra fina azul/ciano de XP
```

A HUD foi reconstruída diretamente do `hud.png` transparente e conferida contra o vídeo do jogo original. A moldura base possui 80×16 px no GBA e é exibida atualmente em escala 1,2× dentro do viewport de 480×270, preservando aproximadamente a mesma proporção de tela do original.

Os elementos usam os sprites reais do sheet, não `ColorRect`s: ícone, divisor amarelo, barra vermelha de HP, barra verde de Ki e barra azul/ciano de experiência. HP e Ki são cortados horizontalmente conforme os valores dos componentes, preservando os highlights e gradientes da pixel art.

Posições nativas medidas no vídeo:

```text
ícone:   (0, 0)
divisor: (22, 3)
HP:      (32, 3)  43×3
Ki:      (29, 7)  43×3
XP:      (2, 12)  73×2
```

A barra de XP agora está conectada ao `ExperienceComponent` e representa o progresso dentro do nível atual. O ícone amarelo é o padrão atual; o ícone azul já pode ser selecionado futuramente pelo sistema de técnicas.

## Progressão RPG

O Player começa no nível 1. O `ExperienceComponent` controla XP, nível e a curva necessária para o próximo nível. O primeiro nível exige 40 XP e a exigência cresce inicialmente em 1,35× por nível.

```text
Enemy defeated
      ↓
ExperienceRewardComponent
      ↓
ExperienceComponent
      ├── experience_changed → HUD
      └── leveled_up
              ↓
       LevelStatsComponent
```

No protótipo, cada level up concede:

- +10 HP máximo;
- +5 Ki máximo;
- +1 dano de soco;
- +1 dano de chute;
- +1 dano do Ki Blast.

O HP e o Ki ganhos no level up também são recuperados imediatamente. O Player pisca em amarelo como feedback visual e o Output registra os novos atributos.

O `DebugGokuEnemy` continua sendo usado como inimigo de validação antes de adicionarmos mobs definitivos. Ele concede 25 XP por derrota. Para acelerar os testes, desaparece brevemente e renasce na posição inicial; o reward é resetado somente no respawn, impedindo múltiplas recompensas para a mesma derrota. Em inimigos reais, `respawn_for_debug` pode ser desligado para que sejam removidos definitivamente.

## Inimigo de teste e IA

O `DebugGokuEnemy` detecta o jogador, persegue, ataca corpo a corpo, reage ao estado `hurt`, sofre knockback e recebe dano de ataques físicos e projéteis. Ao chegar a zero HP ele entra em derrota, desativa colisão/combate, entrega XP uma única vez e desaparece. Por enquanto ele renasce automaticamente apenas para acelerar os testes da progressão.

## Assets locais

Os sprites ripados continuam fora do Git público. Os arquivos esperados localmente são:

```text
assets/sprites/characters/goku/processed/
├── goku_buus_fury_base.png
├── goku_buus_fury_run.png
├── goku_buus_fury_attack.png
├── goku_buus_fury_hurt.png
├── goku_buus_fury_block.png
├── goku_buus_fury_ki_blast.png
├── goku_buus_fury_kick.png
└── goku_buus_fury_charge_ki.png

assets/sprites/effects/processed/
├── ki_blast_projectile.png
└── ki_blast_impact.png

assets/ui/legacy/processed/
├── player_hud_panel.png
└── enemy_hud_panel.png
```

## Princípios

1. Input não altera diretamente o estado do mundo.
2. Combate passa por sistemas/componentes.
3. Personagens são composição de componentes.
4. Vida, Ki, defesa e técnicas são sistemas separados.
5. HUD observa os componentes; não mantém uma segunda fonte de verdade.
6. A camada de rede deve poder substituir a origem dos comandos sem reescrever o personagem.
7. Saves persistem IDs e dados estáveis, não referências diretas a cenas.


## Corrida pixel-perfect

A corrida usa velocidade base de aproximadamente 120 px/s (90 × 1,333333), o que corresponde a 2 px por tick de física a 60 Hz em movimento cardinal. Isso reduz a cadência irregular causada por snapping de pixel.

A câmera do Player não usa smoothing durante o protótipo pixel-art. Com transform snapping ativo, combinar smoothing de câmera com movimento rápido pode causar tremulação aparente do sprite. A animação de corrida também utiliza um spritesheet estabilizado verticalmente, mantendo a base do personagem na mesma linha entre quadros.


## Grande fundação RPG

O protótipo agora possui uma camada maior de sistemas desacoplados para permitir que o conteúdo seja expandido sem concentrar regras no `Player`.

### Inventário e consumíveis

```text
InventoryComponent
├── add_item
├── remove_item
├── quantidade por ID estável
└── serialize/load

ConsumableComponent
└── Senzu Bean → restaura HP + Ki
```

Itens são identificados por `StringName` estável para facilitar save, multiplayer e troca futura de assets.

### Técnicas

`AbilityLoadoutComponent` mantém habilidades desbloqueadas, quatro slots iniciais e cooldowns independentes. O Ki Blast inicial é registrado como habilidade desbloqueada do Player. `AbilityData` fornece o formato data-driven para técnicas futuras como Kamehameha.

### Missões

`QuestManager` vive no Bootstrap e mantém missões ativas/concluídas, objetivos, progresso e recompensas. O Mentor da sala de debug inicia a primeira missão integrada:

```text
Treino Básico
└── derrotar Goku de treino 2 vezes
    ├── 40 XP
    ├── 100 Zeni
    └── 1 Senzu Bean
```

O `QuestTracker` exibe a missão ativa no HUD.

### Diálogo e interação

O Player possui `InteractionSensor`, uma Area2D que detecta objetos na collision layer `Interactables`. Pressionar E chama `interact(actor)` no alvo mais próximo.

`DialogueBox` pausa a SceneTree durante conversas e continua processando input por usar process mode Always.

### Economia

`WalletComponent` armazena Zeni e `ShopComponent` já oferece compra/venda usando `ShopEntryData`. A interface de loja será criada quando o primeiro comerciante definitivo entrar no jogo.

### Save

`SaveManager` usa JSON versionado em `user://save_slot_01.json`. O save atual cobre posição, HP, Ki, XP/nível, inventário, loadout, Zeni, transformações, dano de combate, missões e checkpoint.

O menu de pausa fornece Salvar e Carregar. Conclusões de missão e checkpoints podem disparar autosave.

### Checkpoints

`CheckpointManager` mantém o último checkpoint e o Player consulta esse sistema ao ser derrotado. `CheckpointArea` é um trigger reutilizável e a sala de debug já possui um checkpoint de validação.

### Transformações

`TransformationComponent` e `TransformationData` implementam a base de desbloqueio, ativação, custo inicial, drenagem contínua de Ki e multiplicadores de dano/movimento. Nenhuma forma definitiva foi ligada ao Goku ainda, evitando acoplar Super Saiyan antes das animações e regras estarem definidas.

### Status, loot e inimigos data-driven

- `StatusEffectComponent`: efeitos temporários com magnitude/duração;
- `LootTableComponent`: rolagem de drops configuráveis;
- `EnemyDefinition`: HP, velocidade, dano, ranges, cooldown e XP por dados;
- `LootEntryData`: item, chance e faixa de quantidade.

### Mundo

`WorldManager` troca o conteúdo de `WorldContainer` sem destruir o Bootstrap, mantendo Player, UI e managers persistentes. Isso prepara mapas conectados e transições futuras.

### Feedback e diagnóstico

`NotificationFeed` mostra XP, level up, itens, Zeni, missões e checkpoints. Em builds de debug, `SystemDiagnostics` verifica a presença dos managers e principais componentes do Player ao iniciar.


## Diálogo estilo GBA

O `DialogueBox` agora replica o comportamento observado na referência em vídeo de Buu's Fury:

```text
interação
   ↓
retrato aparece
   ↓
caixa de texto expande horizontalmente
   ↓
texto surge caractere por caractere
   ↓
E / Enter
   ├── durante digitação → completa a página
   └── após completar    → próxima página / fecha
```

O asset local esperado é:

```text
assets/ui/legacy/processed/dialogue_box_font.png
```

O arquivo-fonte possui a moldura de diálogo e o alfabeto bitmap. O runtime remove as duas cores azuis do fundo do rip apenas em memória; o arquivo original não precisa ser alterado.

Geometria usada:

```text
moldura: x=6 y=17 160x62
fonte:   x=172 y=3, grade 13x6, células 15x15
```

A fonte é desenhada por `LegacyDialogueText` diretamente do atlas. O avanço horizontal é menor que a célula do sprite para reproduzir o espaçamento compacto visto no jogo. Caracteres portugueses acentuados são normalizados para suas letras-base porque o atlas original não possui glifos acentuados.

A composição inteira usa escala 2x no viewport 480x270, ficando próxima da proporção do diálogo no GBA. O quadro de retrato usa a mesma borda dourada da caixa com centro ciano. Retratos específicos podem ser passados futuramente pelo terceiro argumento de `show_dialogue(..., portrait_texture_path)`.


## Combat feedback e UX

A camada de combate agora possui feedback desacoplado da lógica de dano.

```text
Hitbox / Ki Blast
      ↓ dano confirmado
Player.register_combat_hit
      ├── ComboTrackerComponent
      └── CombatFeedbackManager
              ├── floating damage text
              └── enemy target health bar
```

O `ComboTrackerComponent` mantém número de golpes, dano acumulado e timeout de 1,25 s. O contador visual só aparece a partir de dois golpes.

`CombatFeedbackManager` também centraliza os números flutuantes de dano. A barra de alvo mostra temporariamente o HP do último inimigo atingido.

Hurtboxes passaram a suportar invulnerability frames configuráveis. O Player começa com 0,35 s após receber dano e o inimigo de treino usa 0,10 s. `receive_hit()` retorna o dano efetivamente aplicado, evitando combo/damage feedback falso quando um golpe é ignorado.

## Loot físico e coleta

Inimigos podem soltar `PickupActor`s no mundo. O pickup atual suporta:

- Zeni;
- itens por ID estável;
- bob vertical;
- lifetime;
- magnetismo de curta distância em direção ao Player.

O Training Fighter deixa 8–18 Zeni por derrota e possui chance inicial de 10% de Senzu Bean.

## Melhorias de IA

O inimigo de treino agora possui detection range, disengage range e leash range separados. Se perseguir o Player para longe demais, retorna ao spawn automaticamente em vez de atravessar o mapa inteiro.

`EncounterSpawner` foi adicionado como backend reutilizável para áreas com respawn e múltiplos pontos de nascimento.

## Checkpoints e morte

Checkpoints agora podem restaurar HP e Ki ao serem ativados, além do autosave existente.

A morte do Player usa `ScreenTransition`: fade para preto, reposicionamento/restauração e fade de retorno. O mesmo overlay já está preparado para trocas de mapa via `WorldManager.load_world_with_transition()`.

## Interface contextual

Novos elementos de UX:

- `InteractionPrompt`: mostra **E Talk to Master Roshi** quando um alvo interagível está próximo;
- `WorldQuestMarker`: exibe ! para quest disponível e ? durante a quest;
- `LocationBanner`: apresenta nomes de regiões ao entrar;
- menu de pausa ampliado com Level, XP, HP, Ki, Zeni, Senzu, KOs, play time e quest ativa;
- uso rápido de Senzu Bean por Q.

A sala de debug é identificada como **TRAINING GROUNDS**.

## Estatísticas persistentes

`GameStatsManager` registra:

- play time;
- damage dealt;
- damage taken;
- enemies defeated;
- items received;
- Zeni received.

Esses dados entram no save versionado a partir da versão 3.

## Controles

`GamepadProfile` registra controles de gamepad em runtime mantendo teclado como fallback. Isso prepara o mesmo fluxo de ações para gamepad e, futuramente, controladores de rede.


## Hierarquia de inteligência dos inimigos

A IA defensiva deixou de ser específica do `DebugGokuEnemy`. `EnemyAIComponent` recebe um `EnemyAIProfile` reutilizável e separa percepção/decisão da apresentação do personagem.

A hierarquia inicial é:

```text
Boss > Elite > Uncommon > Common
```

Os níveis superiores possuem menor tempo de reação, maior percepção de projéteis, maior chance de bloquear corpo a corpo e ataques de Ki, maior chance de esquiva a longa distância, strafing mais frequente e maior chance de contra-atacar depois de uma defesa bem-sucedida.

Fluxo defensivo:

```text
Player attack / combat_projectile
              ↓
       EnemyAIComponent
       ├── BLOCK
       │    └── GuardComponent
       ├── DODGE
       │    └── MovementComponent
       └── NONE
            └── pursuit / attack
```

O bloqueio continua direcional por meio de `GuardComponent`: a IA primeiro vira para a ameaça e só então a guarda reduz o dano. Um bloqueio não aplica hurt/knockback normal e pode gerar um counterattack pendente.

Projéteis pertencem ao grupo `combat_projectile` e expõem origem/direção para percepção. A IA verifica se a trajetória realmente cruza um corredor próximo do inimigo antes de reagir, evitando esquivas falsas.

Os perfis ficam em `data/enemies/ai/`. O Training Fighter usa `uncommon.tres` para validar o sistema. Detalhes e valores iniciais estão em `docs/ENEMY_AI.md`.


## Colisão entre projéteis

Projéteis de combate usam a layer física `Projectiles` e o grupo `combat_projectile`.

O Ki Blast agora detecta outros projéteis por duas camadas:

```text
Area2D overlap
      +
swept segment check por physics frame
```

A checagem contínua existe para evitar tunneling quando dois projéteis rápidos viajam em direções opostas e cruzariam um ao outro entre dois frames.

Fluxo atual:

```text
Projectile A  → ←  Projectile B
        ↓ colisão
posição média do choque
        ↓
A entra em impact
B entra em impact
        ↓
ambos param e desaparecem após impact_duration
```

Nenhum dos dois causa dano ao personagem após o choque.

Quando uma parede e outro projétil podem ser atingidos no mesmo physics frame, o sistema compara a distância do ponto de colisão e resolve o evento mais próximo primeiro.

Contrato preparado para futuros projéteis:

- pertencer ao grupo `combat_projectile`;
- expor `is_active_projectile()`;
- opcionalmente expor `get_projectile_clash_radius()`;
- responder a `receive_projectile_clash(other, position)`.

Isso permite que futuras técnicas tenham raios de colisão diferentes sem acoplar a regra ao Ki Blast.


## Special energy attack catalog

The prototype now has a data-driven special energy layer separate from the rapid Ki Blast.

```text
R
↓
SpecialAttackComponent.select_next()
↓
SpecialAttackHUD

O
↓
SpecialAttackComponent
├── SpecialAttackData
├── KiComponent
├── AbilityLoadoutComponent cooldowns
├── SpecialAttackProjectile
└── SpecialAttackBeam
```

The initial test catalog contains:

- Kamehameha;
- Spirit Bomb;
- Masenko Ha;
- Special Beam Cannon;
- Scatter Shot;
- Big Bang Attack;
- Burning Attack;
- Sword Blast.

The basic Ki Blast remains on K and is not replaced by this catalog.

### Casting presentation

Special attacks expose a cast-pose category:

```text
PROJECTILE
└── special_projectile_* → reuses the Ki Blast arm-forward pose

BEAM
└── special_beam_* → uses goku_buus_fury_beam_cast.png
                     with both hands extended forward
```

The local assets are:

```text
assets/sprites/effects/legacy/special_attack_sfx.png
assets/sprites/characters/goku/processed/goku_buus_fury_beam_cast.png
```

The original effects atlas is kept local rather than committed to the public repository.

### Technique behavior

`SpecialAttackData` controls Ki cost, cooldown, damage, startup, cast lock, projectile speed/size, beam range/width, spread count and optional stun.

Projectile attacks use the existing `combat_projectile` contract, so they collide with opposing Ki Blasts and other special projectiles instead of passing through them. Projectiles from the same caster ignore each other; this is required for Scatter Shot and rapid sequences.

Beam attacks raycast against World geometry to determine their maximum visible/collision length. Master Roshi and other solid world/NPC blockers therefore stop a beam without receiving combat damage.

Burning Attack applies the reusable `stun` status. The Training Fighter now owns a `StatusEffectComponent` and suspends movement, melee, Ki casting and defensive rush behavior while stunned.

The current values are prototype balance. Charge/sustain timing and character-specific unlock rules can be tuned without changing the projectile/beam architecture.
