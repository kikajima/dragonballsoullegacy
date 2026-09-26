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
│   ├── KickCombatComponent
│   ├── HitStopComponent
│   ├── HealthComponent
│   ├── KnockbackComponent
│   ├── GuardComponent
│   ├── KiComponent
│   └── KiBlastComponent
├── Hurtbox
├── Controllers
│   └── PlayerInputController
└── Camera2D
```

Estados atuais do jogador:

```text
idle
walk
attack_1
attack_2
kick
hurt
block
ki_blast
charge_ki
```

## Combate físico

**J** usa o `MeleeCombatComponent` e alterna os dois socos do combo.

**I** usa um `KickCombatComponent` separado. O chute tem animação, duração, janela de hitbox e dano próprios. No protótipo ele é mais lento e mais forte que um soco.

O `AttackHitbox` é compartilhado pelos ataques físicos, mas cada componente define explicitamente o dano ao iniciar sua ação. Isso evita que o dano de um chute permaneça configurado no próximo soco.

## Defesa

O `GuardComponent` mantém o estado de defesa separado da lógica do Player. A defesa verifica a direção do personagem e a posição de origem do golpe.

Golpes recebidos pela frente são reduzidos para 25% do dano original no protótipo. Golpes por trás ignoram a defesa. Um golpe bloqueado não coloca o jogador no estado `hurt` nem aplica knockback.

## Ki e técnicas

`KiComponent` concentra o recurso de Ki e expõe consumo, recuperação e sinais de mudança.

O primeiro ataque de energia é o Ki Blast:

```text
K
↓
KiBlastComponent
├── verifica e consome Ki
├── controla o tempo da animação
└── instancia KiBlastProjectile
        ↓
    Hurtbox inimiga
        ↓
    HealthComponent
```

O projétil usa os frames reais do spritesheet local de efeitos quando o arquivo processado está presente. Se o asset estiver ausente, permanece um fallback geométrico para o projeto continuar executando.

Ao segurar **L**, o Player entra em `charge_ki`, fica parado, reproduz a animação de carregamento extraída do spritesheet do Goku e recupera Ki.

## HUD

`CombatHUD` fica no `UIContainer` do bootstrap e observa os componentes, sem duplicar os valores de gameplay:

```text
HealthComponent ──→ barra HP do jogador
KiComponent ──────→ barra Ki do jogador
Enemy Health ─────→ barra HP do inimigo
```

Quando os recortes locais de `Player HUD` estão disponíveis, eles são usados como moldura visual. Sem esses arquivos, o HUD mantém um fallback funcional.

## Inimigo de teste e IA

O `DebugGokuEnemy` detecta o jogador, persegue, ataca corpo a corpo, reage ao estado `hurt`, sofre knockback e recebe dano de ataques físicos e projéteis. Ele pertence ao grupo `enemy`, permitindo que a HUD encontre sua vida sem depender de um caminho de cena fixo.

## Assets locais

Os sprites ripados continuam fora do Git público. Os novos arquivos esperados localmente são:

```text
assets/sprites/characters/goku/processed/
├── goku_buus_fury_base.png
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
