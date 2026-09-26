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
| Carregar Ki | L |
| Dash | Espaço |
| Defender | Shift esquerdo |
| Interagir | E |

## Combate atual

- **J:** alterna `attack_1` e `attack_2`, usando os dois socos.
- **I:** alterna `kick_1` e `kick_2`, usando as duas pernas.
- Socos e chutes compartilham o mesmo buffer de combo. É possível encadear livremente sequências como `J → I → J → I`, `J → J → I` ou `I → I → J`.
- O chute é um pouco mais lento, alcança mais longe e causa mais dano que o soco.
- **Shift esquerdo:** mantém a defesa ativa. Enquanto defende, o personagem fica completamente parado, mas ainda pode trocar a direção usando WASD/setas.
- A defesa só reduz golpes recebidos pela frente; ataques por trás continuam causando dano normal.
- **K:** dispara um Ki Blast, consumindo Ki.
- **L:** mantém o personagem parado, toca a animação de carregamento e recupera Ki.

O `PlayerInputController` traduz dispositivos de entrada em intenções de jogo. A lógica do personagem não lê teclas diretamente, permitindo adicionar gamepad e controle por rede sem reescrever o movimento.
