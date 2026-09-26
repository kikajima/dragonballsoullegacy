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

O jogador alterna entre `idle`, `walk`, `attack_1` e `attack_2`. O `FacingComponent` acompanha imediatamente a direção de movimento, inclusive durante ataques.

Cada soco, porém, guarda sua própria direção dentro do `MeleeCombatComponent`. Isso impede que a hitbox gire no meio de um golpe, mas permite que o próximo soco da sequência saia na nova direção sem o atraso de esperar toda a animação anterior terminar.

## Combate corpo a corpo

O fluxo atual é:

```text
attack (Input)
      ↓
PlayerInputController
      ↓
FacingComponent atualiza direção desejada
      ↓
MeleeCombatComponent
      ├── alterna attack_1 / attack_2
      ├── guarda direção do golpe atual
      ├── possui janela de combo/cancel
      ├── possui input buffer
      └── ativa/desativa AttackHitbox
                       ↓
                HitboxComponent
                       ↓
                HurtboxComponent
                       ↓
                HealthComponent
```

Cada pressionamento corresponde a um soco. Se o próximo ataque for pedido cedo, ele fica no buffer. Assim que a janela de encadeamento abre, esse input é consumido imediatamente. Se o botão for pressionado depois que a janela já abriu, o próximo soco começa na hora.

Isso mantém o ataque atual coerente, permite trocar de direção rapidamente entre socos e evita a sensação de atraso ao alternar lados durante uma sequência.

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
