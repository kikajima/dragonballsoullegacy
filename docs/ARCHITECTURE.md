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
│   └── KnockbackComponent
├── Hurtbox
├── Controllers
│   └── PlayerInputController
└── Camera2D
```

O jogador possui `idle`, `walk`, `attack_1`, `attack_2` e `hurt`. Ao receber um golpe, o ataque atual é cancelado, a direção vira para a origem do impacto, a animação `hurt` é executada e o knockback assume o movimento por um curto período.

## Combate corpo a corpo

Cada pressionamento corresponde a um soco. O combo usa input buffer e janela de encadeamento com cadência legível:

- animação de ataque do jogador: 10 FPS;
- duração aproximada do golpe: 0,40 s;
- hitbox ativa entre 0,11 s e 0,29 s;
- próximo soco pode encadear a partir de 0,26 s.

O jogador continua podendo se deslocar durante o golpe com velocidade reduzida.

## Inimigo de teste e IA

O `DebugGokuEnemy` agora é um inimigo funcional de curto alcance. Ele procura um nó no grupo `player`, detecta o jogador dentro do raio configurado, persegue usando a animação de caminhada e inicia um ataque quando chega ao alcance.

```text
DebugGokuEnemy
├── Visuals
│   └── AnimatedSprite2D
├── CollisionShape2D
├── Combat
│   └── AttackHitbox
├── Components
│   ├── HealthComponent
│   ├── MovementComponent
│   ├── KnockbackComponent
│   ├── StateMachine
│   └── MeleeCombatComponent
└── Hurtbox
```

Estados usados atualmente:

```text
idle
walk
attack_1
attack_2
hurt
```

A lógica de combate do inimigo respeita o estado `hurt`: enquanto sofre dano e knockback, ele não persegue nem ataca. Depois da reação, volta a avaliar a posição do jogador.

Parâmetros iniciais do protótipo:

- raio de detecção: 170 px;
- alcance de ataque: 25 px;
- velocidade de perseguição: 55 px/s;
- dano por soco: 8;
- intervalo após um ataque: 0,55 s;
- animação de ataque do inimigo: 8 FPS.

## Impacto, dano e reação

O mesmo fluxo de componentes vale nos dois sentidos:

```text
AttackHitbox
    ↓
HitboxComponent
    ↓
HurtboxComponent
    ↓
HealthComponent
    ↓
estado hurt
    ├── animação hurt direcional
    └── KnockbackComponent
```

O jogador agora também possui `HealthComponent`, `HurtboxComponent` e `KnockbackComponent`, portanto o inimigo pode realmente causar dano. Para facilitar os testes, se o HP do jogador ou do inimigo chegar a zero, HP e posição são restaurados.

Os sprites locais utilizados continuam sendo:

```text
goku_buus_fury_base.png
goku_buus_fury_attack.png
goku_buus_fury_hurt.png
```

Esses assets permanecem fora do Git público.

## Princípios

1. Input não altera diretamente o estado do mundo.
2. Combate passa por sistemas/componentes, evitando dano aplicado de forma espalhada.
3. Personagens são composição de componentes.
4. Dados de personagem e habilidade ficam separados da lógica.
5. A camada de rede deve poder substituir a origem dos comandos sem reescrever o personagem.
6. Saves persistem IDs e dados estáveis, não referências diretas a cenas.
