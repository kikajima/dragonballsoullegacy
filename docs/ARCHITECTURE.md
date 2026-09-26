# Arquitetura

O projeto é organizado para manter lógica, dados, apresentação e rede desacoplados.

## Diretórios principais

- `actors/`: jogador, inimigos e NPCs.
- `assets/`: sprites, tilesets, fontes, músicas e efeitos sonoros.
- `components/`: componentes reutilizáveis como vida, Ki, movimento, direção, state machine, hitbox e hurtbox.
- `combat/`: regras de combate, dano, projéteis e técnicas.
- `core/`: serviços centrais do jogo.
- `data/`: Resources e dados de personagens/conteúdo.
- `network/`: multiplayer e replicação futura.
- `quests/`: sistema de missões.
- `rpg/`: XP, níveis, inventário, equipamentos, progressão e transformações.
- `scenes/`: cenas de bootstrap e depuração.
- `ui/`: HUD, menus e interfaces.
- `world/`: mapas, transições, spawns, portas e objetos interativos.

## Player atual

```text
Player
├── Visuals
│   ├── AnimatedSprite2D
│   ├── Placeholder
│   │   └── FacingMarker
│   └── AnimationController
├── CollisionShape2D
├── Combat
│   └── AttackHitbox
├── Components
│   ├── MovementComponent
│   ├── FacingComponent
│   ├── StateMachine
│   └── MeleeCombatComponent
├── Controllers
│   └── PlayerInputController
└── Camera2D
```

O jogador alterna entre `idle`, `walk`, `attack_1` e `attack_2`. O `FacingComponent` mantém a última direção cardinal observada: `up`, `down`, `left` ou `right`.

O `PlayerAnimationController` utiliza a convenção:

```text
idle_up
idle_down
idle_left
idle_right

walk_up
walk_down
walk_left
walk_right

attack_1_up
attack_1_down
attack_1_left
attack_1_right

attack_2_up
attack_2_down
attack_2_left
attack_2_right
```

As animações de movimento e ataque usam spritesheets locais ignorados pelo Git por conterem recursos de terceiros.

## Combate corpo a corpo

O fluxo atual é:

```text
attack (Input)
      ↓
PlayerInputController
      ↓
MeleeCombatComponent
      ├── alterna attack_1 / attack_2
      ├── mantém uma janela de input buffer
      ├── controla duração do golpe
      └── ativa/desativa AttackHitbox
                       ↓
                HitboxComponent
                       ↓
                HurtboxComponent
                       ↓
                HealthComponent
```

Cada pressionamento de ataque corresponde a um único soco. Os golpes alternam entre duas animações e o personagem continua se movimentando durante o ataque com velocidade reduzida.

O input buffer mantém por um curto intervalo um comando de ataque feito perto do final do golpe atual. Se ainda estiver válido quando o golpe termina, o próximo soco começa imediatamente, evitando a necessidade de apertar o botão em um frame exato.

## Dano, vida e hurtbox

`HealthComponent` concentra HP, dano, cura, morte e sinais de mudança de vida. `HurtboxComponent` recebe a colisão do golpe e encaminha o dano para o `HealthComponent`.

A sala de depuração usa o fluxo real de componentes:

```text
DebugTarget
├── Visual
├── Components
│   └── HealthComponent
└── Hurtbox
    └── CollisionShape2D
```

Esse alvo continua restaurando a própria vida ao chegar a zero para facilitar testes repetidos.

## Princípios

1. Input não altera diretamente o estado do mundo.
2. Combate passa por sistemas/componentes, evitando dano aplicado de forma espalhada.
3. Personagens são composição de componentes.
4. Dados de personagem e habilidade ficam separados da lógica.
5. A camada de rede deve poder substituir a origem dos comandos sem reescrever o personagem.
6. Saves persistem IDs e dados estáveis, não referências diretas a cenas.
