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
├── Components
│   ├── MovementComponent
│   ├── FacingComponent
│   └── StateMachine
├── Controllers
│   └── PlayerInputController
└── Camera2D
```

O jogador começa com dois estados de movimento: `idle` e `walk`. O `FacingComponent` mantém a última direção cardinal observada: `up`, `down`, `left` ou `right`.

O `PlayerAnimationController` procura animações com a convenção:

```text
idle_up
idle_down
idle_left
idle_right
walk_up
walk_down
walk_left
walk_right
```

Enquanto essas animações ainda não possuem sprites, o placeholder mostra a direção por uma pequena seta branca e uma animação simples de movimento.

## Princípios

1. Input não altera diretamente o estado do mundo.
2. Combate passa por sistemas/componentes, evitando dano aplicado de forma espalhada.
3. Personagens são composição de componentes.
4. Dados de personagem e habilidade ficam separados da lógica.
5. A camada de rede deve poder substituir a origem dos comandos sem reescrever o personagem.
6. Saves persistem IDs e dados estáveis, não referências diretas a cenas.
