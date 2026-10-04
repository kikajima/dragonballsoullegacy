# Comparação com as referências locais

## Fontes conferidas

- `../HeroesUnited2-master/Code/Beams.dm` e a versão em `../HeroesUnited2Dev-master/Code/Beams.dm`.
- `../HeroesUnited2-master/Code/Movement.dm`.
- Sprites recortados em `assets/sprites/characters/goku/processed`, efeitos em `assets/sprites/effects/legacy` e HUD em `assets/ui/legacy`.
- Implementações atuais do jogador, ilha, HUD e ataques especiais.

A biblioteca completa de GBA descrita em `SPRITE_LIBRARY.md` não está presente neste checkout: nem `assets/vendor/dragon_ball_gba` nem `assets/vendor/gba` existem. Os recortes existentes não permitem confirmar o conjunto completo de mapas, animações e telas enviado anteriormente. A comparação visual integral permanece pendente da localização desse material.

## Diferenças verificáveis

| Sistema | Referência / evidência | Projeto atual |
| --- | --- | --- |
| Contato do feixe | HU2 `Beam()` muda a última peça para `Hit` e executa `goto END` ao encontrar o primeiro adversário elegível. | A seleção do obstáculo consultava `can_receive_hit()`, excluindo o alvo durante a invulnerabilidade após dano. Corrigido: alvo vivo e monitorável continua bloqueando. |
| Duração do feixe | HU2 aplica até cinco pulsos em `BeamHit()` com `sleep(3)` e limpa o feixe após `sleep(15)` fora de duelos. | Feixe sustentado pelo botão e consumo contínuo de Ki. É uma diferença de regra, não uma reprodução de HU2. |
| Montagem visual | HU2 constrói peças nos tiles sucessivos e termina na peça de impacto. | Movimento contínuo exige ajustar o último trecho à distância real do alvo. Corrigido o mínimo de 32 pixels que ultrapassava inimigos próximos. |
| Movimento | HU2 usa `step()` em oito direções, com intervalo entre passos e corrida por duplo toque. | `CharacterBody2D` com deslocamento contínuo. Trocar apenas sprites não reproduz o ritmo original. |
| Ilha | Falta a biblioteca completa para comparar o mapa enviado. | `kame_island.gd` monta terreno com tiles HU2, polígonos de costa e linhas de espuma animadas. Os comentários de inspiração não comprovam fidelidade ao mapa GBA. |
| Interface / personagens | Há recortes GBA e estados DMI HU2 no projeto. | HUD mistura recortes Legacy e ícones HU2; nomes de arquivos e presença dos sprites não garantem composição ou animação fiel. |

## Correção de contato realizada

- Invulnerabilidade bloqueia dano, mas não faz o feixe atravessar o alvo.
- Geometria atualizada a cada passo de física, independentemente da cadência de dano.
- Ponta visual cabe entre a origem e o limite frontal do inimigo, inclusive a curta distância.
- Segundo inimigo alinhado fica protegido enquanto o primeiro está vivo, inclusive durante invulnerabilidade.
- Alvo morto deixa de bloquear o feixe.

Teste reproduzível:

```powershell
& "$env:USERPROFILE/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/test_beam_contact.gd
```

O teste cobre quatro direções cardinais e três distâncias, com dois alvos alinhados, dano, invulnerabilidade, limites das peças visuais e morte do primeiro alvo. Não substitui revisão visual jogável nem comprova reconstrução integral do jogo.

## Trabalho restante

Localizar os arquivos GBA completos e definir quais regras vêm de cada referência antes de reconstruir mapas, interface e ritmo de combate. HU2 e Legacy não são intercambiáveis; reproduzir movimento em grade e disparos de duração fixa é uma escolha diferente de preservar o controle contínuo atual. A correção de contato não encerra esse trabalho maior.
