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

O jogador possui três estados atuais: `idle`, `walk` e `attack`. O `FacingComponent` mantém a última direção cardinal observada: `up`, `down`, `left` ou `right`.

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

attack_up
attack_down
attack_left
attack_right
```

As animações de movimento usam um spritesheet local e as animações de ataque usam outro spritesheet local, ambos ignorados pelo Git por conterem recursos de terceiros.

## Combate corpo a corpo

O fluxo atual é:

```text
attack (Input)
      ↓
PlayerInputController
      ↓
Player muda para estado attack
      ↓
MeleeCombatComponent
      ├── controla duração do golpe
      └── ativa/desativa AttackHitbox
                       ↓
                HitboxComponent
                       ↓
               alvo com receive_hit()
```

Durante o ataque o movimento é interrompido. A hitbox só fica ativa durante a janela útil do golpe e registra cada alvo uma única vez por ataque.

A sala de depuração possui um `DebugTarget` temporário para validar dano e alcance antes da criação do sistema real de inimigos.

## Princípios

1. Input não altera diretamente o estado do mundo.
2. Combate passa por sistemas/componentes, evitando dano aplicado de forma espalhada.
3. Personagens são composição de componentes.
4. Dados de personagem e habilidade ficam separados da lógica.
5. A camada de rede deve poder substituir a origem dos comandos sem reescrever o personagem.
6. Saves persistem IDs e dados estáveis, não referências diretas a cenas.
