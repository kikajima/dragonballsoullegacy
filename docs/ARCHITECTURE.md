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
kick_1
kick_2
hurt
block
ki_blast
charge_ki
```

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
HealthComponent ──→ barra HP do jogador
KiComponent ──────→ barra Ki do jogador
Enemy Health ─────→ barra HP do inimigo
```

Quando os recortes locais de `Player HUD` estão disponíveis, eles são usados em escala nativa de pixel (1:1 no viewport interno de 480×270). As barras de HP/Ki e a barra do inimigo são preenchimentos dinâmicos alinhados aos slots do sprite original; os valores numéricos de depuração foram removidos da apresentação. Sem esses arquivos, o HUD mantém um fallback funcional.

## Inimigo de teste e IA

O `DebugGokuEnemy` detecta o jogador, persegue, ataca corpo a corpo, reage ao estado `hurt`, sofre knockback e recebe dano de ataques físicos e projéteis. Ele pertence ao grupo `enemy`, permitindo que a HUD encontre sua vida sem depender de um caminho de cena fixo.

## Assets locais

Os sprites ripados continuam fora do Git público. Os arquivos esperados localmente são:

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
