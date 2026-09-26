# Arquitetura

O projeto é organizado para manter lógica, dados, apresentação e rede desacoplados.

## Diretórios principais

- `actors/`: jogador, inimigos e NPCs.
- `assets/`: sprites, tilesets, fontes, músicas e efeitos sonoros.
- `components/`: componentes reutilizáveis como vida, Ki, movimento, direção, state machine, hitbox, hurtbox, knockback e hit stop.
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
│   ├── MeleeCombatComponent
│   └── HitStopComponent
├── Controllers
│   └── PlayerInputController
└── Camera2D
```

O jogador alterna entre `idle`, `walk`, `attack_1` e `attack_2`. O `FacingComponent` acompanha imediatamente a direção de movimento, inclusive durante ataques.

Cada soco guarda sua própria direção dentro do `MeleeCombatComponent`, evitando que a hitbox gire no meio do golpe e permitindo mudar a direção do próximo soco da sequência.

## Combate corpo a corpo

Cada pressionamento corresponde a um soco. O combo usa input buffer e janela de encadeamento, mas a cadência foi ajustada para ficar mais legível:

- animação de ataque: 10 FPS;
- duração aproximada do golpe: 0,40 s;
- hitbox ativa entre 0,11 s e 0,29 s;
- próximo soco pode encadear a partir de 0,26 s.

O jogador continua podendo se deslocar durante o golpe com velocidade reduzida.

## Impacto, dano e reação

O fluxo de dano atual é:

```text
AttackHitbox
    ↓
HitboxComponent
    ↓
HurtboxComponent
    ↓
HealthComponent
    ↓
estado hurt + KnockbackComponent
```

Quando um golpe é confirmado, o `HitStopComponent` reduz o tempo global por alguns milissegundos para dar sensação de impacto.

O inimigo de teste agora é outro Goku e utiliza o mesmo spritesheet local do jogador:

```text
DebugGokuEnemy
├── Visuals
│   └── AnimatedSprite2D
├── CollisionShape2D
├── Components
│   ├── HealthComponent
│   ├── KnockbackComponent
│   └── StateMachine
└── Hurtbox
```

Ao ser atingido ele entra brevemente no estado `hurt`, pisca em vermelho e sofre knockback. Ao perder todo o HP, sua vida e posição são restauradas para continuar os testes.

## Princípios

1. Input não altera diretamente o estado do mundo.
2. Combate passa por sistemas/componentes, evitando dano aplicado de forma espalhada.
3. Personagens são composição de componentes.
4. Dados de personagem e habilidade ficam separados da lógica.
5. A camada de rede deve poder substituir a origem dos comandos sem reescrever o personagem.
6. Saves persistem IDs e dados estáveis, não referências diretas a cenas.
