# Controles

Mapeamento atual do protótipo.

| Ação | Teclado |
| --- | --- |
| Mover para cima | W / ↑ |
| Mover para baixo | S / ↓ |
| Mover para esquerda | A / ← |
| Mover para direita | D / → |
| Soco / combo | J |
| Chute / combo | I |
| Ki Blast | K |
| Usar técnica especial | O |
| Próxima técnica especial | R |
| Carregar Ki | L |
| Correr | Segurar Espaço |
| Defender | Shift esquerdo |
| Interagir | E |
| Usar Senzu Bean rápido | Q |
| Pausar | Esc |

## Combate atual

- **J:** alterna `attack_1` e `attack_2`, usando os dois socos.
- **I:** alterna `kick_1` e `kick_2`, usando as duas pernas.
- Socos e chutes compartilham o mesmo buffer de combo. É possível encadear livremente sequências como `J → I → J → I`, `J → J → I` ou `I → I → J`.
- O chute é um pouco mais lento, alcança mais longe e causa mais dano que o soco.
- **Shift esquerdo:** mantém a defesa ativa. Enquanto defende, o personagem fica completamente parado, mas ainda pode trocar a direção usando WASD/setas.
- A defesa só reduz golpes recebidos pela frente; ataques por trás continuam causando dano normal.
- **K:** dispara Ki Blasts pequenos. Um toque faz um disparo; manter K pressionado cria uma sequência contínua. O primeiro tiro tem uma preparação curta e os seguintes alternam diretamente entre braço esquerdo e direito em cadência regular. Toques adicionais também entram no buffer. O personagem permanece parado durante toda a sequência, mas pode mudar a direção do próximo disparo.
- **Espaço + direção:** faz o personagem correr. A corrida usa animação própria e velocidade maior; soltar Espaço volta imediatamente para a caminhada.
- **L:** mantém o personagem parado, toca a animação de carregamento e recupera Ki.

O `PlayerInputController` traduz dispositivos de entrada em intenções de jogo. A lógica do personagem não lê teclas diretamente, permitindo adicionar gamepad e controle por rede sem reescrever o movimento.


## Gamepad

Um perfil de gamepad é registrado em runtime sem remover os controles de teclado.

| Ação | Gamepad |
| --- | --- |
| Movimento | Analógico esquerdo / D-pad |
| Interagir | A |
| Ki Blast | B |
| Soco | X |
| Chute | Y |
| Defender | LB |
| Correr | RB |
| Senzu Bean rápido | LT |
| Carregar Ki | RT |
| Pausar | Start |

O mapeamento fica em `core/input/gamepad_profile.gd` para poder ser alterado depois sem reescrever o Player.


## Special energy attacks

The prototype currently unlocks the complete Legacy of Goku II special-energy test catalog so the effects and combat rules can be validated before character-specific progression is enforced.

- **R:** cycle the selected special technique.
- **O:** cast the selected technique.
- **K:** remains the rapid basic Ki Blast.
- **L:** remains Ki charge.

Current test catalog:

1. Kamehameha
2. Spirit Bomb
3. Masenko Ha
4. Special Beam Cannon
5. Scatter Shot
6. Big Bang Attack
7. Burning Attack
8. Sword Blast

Projectile techniques reuse the Ki Blast-style casting pose. Beam techniques use the separate two-handed forward casting pose.


## Técnicas especiais

O protótipo atual libera todas as técnicas para Goku, independentemente do personagem original de Legacy of Goku II. Isso é intencional para validar o modelo futuro de personagem customizável do MMORPG.

- **R:** percorre todas as técnicas conhecidas.
- **O:** executa a técnica selecionada.
- Técnicas como Kamehameha e Special Beam Cannon ficam ativas enquanto O estiver pressionado.
- Spirit Bomb, Big Bang Attack, Masenko Ha, Scatter Shot e os golpes melee carregáveis usam **segurar O → soltar O**.
- A HUD de técnicas mostra quando a habilidade está em carga, sustentada ou em cooldown.
