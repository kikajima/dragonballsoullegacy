# Controles

Mapeamento inicial do protótipo.

| Ação | Teclado |
| --- | --- |
| Mover para cima | W / ↑ |
| Mover para baixo | S / ↓ |
| Mover para esquerda | A / ← |
| Mover para direita | D / → |
| Ataque corpo a corpo | J |
| Ki Blast | K |
| Dash | Espaço |
| Defender | Shift esquerdo |
| Carregar Ki | L |
| Interagir | E |

## Combate atual

- **J:** alterna os dois socos do combo.
- **Shift esquerdo:** mantém a defesa ativa e reduz a velocidade de movimento.
- A defesa só reduz golpes recebidos pela frente; ataques por trás continuam causando dano normal.
- **K:** dispara um Ki Blast, consumindo Ki.
- **L:** mantém o personagem parado enquanto recupera Ki.

O `PlayerInputController` traduz dispositivos de entrada em intenções de jogo. A lógica do personagem não lê teclas diretamente, permitindo adicionar gamepad e controle por rede sem reescrever o movimento.
