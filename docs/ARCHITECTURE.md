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
hurt
block
ki_blast
charge_ki
```

## Defesa

O `GuardComponent` mantém o estado de defesa separado da lógica do Player. A defesa verifica a direção do personagem e a posição de origem do golpe.

Golpes recebidos pela frente são reduzidos para 25% do dano original no protótipo. Golpes por trás ignoram a defesa. Um golpe bloqueado não coloca o jogador no estado `hurt` nem aplica knockback.

O jogador pode se deslocar durante a defesa, mas com velocidade reduzida.

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

Parâmetros iniciais:

- Ki máximo: 100;
- custo do Ki Blast: 12;
- dano do projétil: 12;
- velocidade do projétil: 210 px/s;
- recarga manual de Ki: 28 por segundo;
- durante a recarga o jogador permanece parado.

O Ki Blast usa a camada física `Projectiles` e pode atingir Hurtboxes inimigas ou desaparecer ao atingir o mundo.

## Combate corpo a corpo

Cada pressionamento de J corresponde a um soco. O combo usa input buffer e janela de encadeamento:

- animação do jogador: 10 FPS;
- duração aproximada: 0,40 s;
- hitbox ativa entre 0,11 s e 0,29 s;
- encadeamento disponível a partir de 0,26 s.

## Inimigo de teste e IA

O `DebugGokuEnemy` detecta o jogador, persegue, ataca corpo a corpo, reage ao estado `hurt`, sofre knockback e recebe dano de ataques físicos e projéteis.

## Assets locais

Os sprites processados continuam fora do Git público:

```text
goku_buus_fury_base.png
goku_buus_fury_attack.png
goku_buus_fury_hurt.png
goku_buus_fury_block.png
goku_buus_fury_ki_blast.png
```

## Princípios

1. Input não altera diretamente o estado do mundo.
2. Combate passa por sistemas/componentes.
3. Personagens são composição de componentes.
4. Vida, Ki, defesa e técnicas são sistemas separados.
5. A camada de rede deve poder substituir a origem dos comandos sem reescrever o personagem.
6. Saves persistem IDs e dados estáveis, não referências diretas a cenas.
