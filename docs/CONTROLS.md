# Controles

Mapeamento atual do protótipo.

| Ação | Teclado |
| --- | --- |
| Mover para cima | W / ↑ |
| Mover para baixo | S / ↓ |
| Mover para esquerda | A / ← |
| Mover para direita | D / → |
| Soco / combo | J |
| Chute | I |
| Ki Blast | K |
| Carregar Ki | L |
| Dash | Espaço |
| Defender | Shift esquerdo |
| Interagir | E |

## Combate atual

- **J:** alterna os dois socos do combo, com input buffer.
- **I:** executa um chute separado, mais lento e mais forte que o soco.
- **Shift esquerdo:** mantém a defesa ativa e reduz a velocidade de movimento.
- A defesa só reduz golpes recebidos pela frente; ataques por trás continuam causando dano normal.
- **K:** dispara um Ki Blast, consumindo Ki.
- **L:** mantém o personagem parado, toca a animação de carregamento e recupera Ki.

O `PlayerInputController` traduz dispositivos de entrada em intenções de jogo. A lógica do personagem não lê teclas diretamente, permitindo adicionar gamepad e controle por rede sem reescrever o movimento.
