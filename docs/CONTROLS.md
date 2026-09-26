# Controles

Mapeamento inicial do protótipo.

| Ação | Teclado |
| --- | --- |
| Mover para cima | W / ↑ |
| Mover para baixo | S / ↓ |
| Mover para esquerda | A / ← |
| Mover para direita | D / → |
| Ataque | J |
| Ki Blast | K |
| Dash | Espaço |
| Bloqueio | Shift esquerdo |
| Carregar Ki | L |
| Interagir | E |

O `PlayerInputController` traduz dispositivos de entrada em intenções de jogo. A lógica do personagem não lê teclas diretamente, permitindo adicionar gamepad e controle por rede sem reescrever o movimento.
