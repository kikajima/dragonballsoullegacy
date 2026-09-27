# Checklist de validação do grande update

Este documento existe porque o update adicionou vários sistemas de uma só vez e deve ser validado em blocos quando o projeto puder ser testado novamente.

## 1. Inicialização

- Abrir o projeto sem erros de parser.
- Rodar `bootstrap.tscn`.
- Confirmar no Output: `DBSL diagnostics: core systems found.`
- HUD continua aparecendo corretamente.
- Player continua andando, correndo, atacando, defendendo, carregando Ki e disparando Ki Blast.

## 2. Interação e diálogo

- Confirmar que existe o arquivo local `assets/ui/legacy/processed/dialogue_box_font.png`.
- Aproximar-se do Mentor na sala de debug.
- Pressionar **E**.
- O retrato deve aparecer primeiro e a moldura verde/dourada deve expandir horizontalmente.
- O texto deve usar a fonte bitmap do sprite sheet e surgir caractere por caractere.
- O mundo deve permanecer pausado durante o diálogo.
- E / Enter durante a digitação deve completar imediatamente a página.
- E / Enter depois de completar deve avançar para a próxima página.
- Ao terminar, a caixa deve recolher horizontalmente e o jogo voltar a rodar.

## 3. Missões

- Conversar com o Mentor pela primeira vez.
- A missão `Treino Básico` deve iniciar.
- O tracker deve mostrar 0/2.
- Derrotar o Goku de treino uma vez: 1/2.
- Derrotar novamente: missão concluída.
- Recompensas esperadas: +40 XP, +100 Zeni e 1 `senzu_bean`.

## 4. Progressão

- Cada Goku de treino concede 25 XP por derrota.
- Barra azul/ciano da HUD deve refletir XP.
- Level up deve aumentar:
  - +10 HP máximo;
  - +5 Ki máximo;
  - +1 soco;
  - +1 chute;
  - +1 Ki Blast.
- Notificação de LEVEL UP deve aparecer.

## 5. Inventário

- Após concluir a missão, `InventoryComponent.get_quantity(&"senzu_bean")` deve retornar 1.
- `Player.use_inventory_item(&"senzu_bean")` deve restaurar HP e Ki e consumir 1 unidade.
- Item não deve ser consumido se HP e Ki já estiverem cheios.

## 6. Economia

- A missão deve adicionar 100 Zeni ao `WalletComponent`.
- `ShopComponent` suporta compra e venda, mas ainda não possui interface gráfica.
- Validar futuramente com uma loja/NPC real.

## 7. Checkpoint

- Entrar no círculo azul da sala de treino.
- Deve aparecer a notificação de checkpoint.
- O checkpoint deve gerar autosave.
- Se o jogador morrer depois, deve reaparecer na posição salva pelo checkpoint.

## 8. Save / Load

- Pressionar Esc.
- Menu de pausa deve abrir.
- Testar Salvar.
- Alterar posição/HP/Ki e testar Carregar.
- Confirmar restauração de:
  - posição;
  - HP e Ki;
  - nível e XP;
  - inventário;
  - habilidades desbloqueadas/equipadas;
  - Zeni;
  - transformações desbloqueadas;
  - dano de soco/chute/Ki Blast;
  - missões;
  - checkpoint.

## 9. Pause

- Esc deve pausar o jogo.
- Continuar deve restaurar o gameplay.
- Esc durante um diálogo não deve abrir o menu de pausa por cima.

## 10. Sistemas preparados para conteúdo futuro

Os sistemas abaixo já possuem backend, mas ainda precisam de conteúdo/UI definitivo:

- `AbilityLoadoutComponent`: técnicas desbloqueáveis, slots e cooldowns;
- `TransformationComponent`: formas, custo e drenagem de Ki;
- `StatusEffectComponent`: buffs/debuffs temporários;
- `LootTableComponent`: drops por chance;
- `ShopComponent`: compra e venda;
- `WorldManager`: troca de mapas dentro do bootstrap;
- `EnemyDefinition`: definição data-driven de mobs;
- `ItemData`, `AbilityData`, `QuestDefinition`, `TransformationData`: Resources de conteúdo.

## Ordem sugerida de correção

Se algo quebrar, validar nesta ordem:

1. erros de parser;
2. Player e combate;
3. HUD;
4. XP;
5. interação/diálogo;
6. quests;
7. checkpoint;
8. save/load;
9. inventário/economia;
10. sistemas futuros.


## 11. Combat feedback update

- Confirmar que dano corpo a corpo mostra número flutuante.
- Confirmar que Ki Blast também registra o dano uma única vez.
- Dois ou mais golpes devem abrir o combo counter.
- Após ~1,25 s sem acertar, o combo deve desaparecer.
- Receber dano deve quebrar o combo.
- Atacar durante invulnerability frames não deve gerar falso HIT.
- Ao acertar inimigo, barra de HP contextual deve surgir no topo.

## 12. Loot e quick item

- Derrotar Training Fighter deve criar pickup de Zeni.
- Pickup próximo deve ser puxado para o Player.
- Coletar deve aumentar Wallet.
- Eventual Senzu drop deve aumentar Inventory.
- Q deve consumir Senzu se HP ou Ki não estiverem cheios.
- Q não deve consumir item desnecessariamente.

## 13. UX contextual

- Aproximar de Master Roshi deve mostrar `E Talk to Master Roshi`.
- Roshi deve mostrar ! antes da missão, ? durante e esconder após conclusão.
- Entrar na região inicial deve mostrar `TRAINING GROUNDS`.
- Esc deve mostrar status, quest, Zeni, Senzu, KOs e play time.

## 14. Respawn e transições

- Morrer deve iniciar fade para preto.
- Player deve reaparecer no checkpoint ou spawn.
- HP/Ki devem ser restaurados.
- Fade deve voltar ao gameplay.
- Ativar checkpoint deve recuperar HP/Ki e autosalvar.

## 15. Gamepad

- Analógico e D-pad devem mover.
- A interage.
- B dispara Ki.
- X soca.
- Y chuta.
- LB defende.
- RB corre.
- LT usa Senzu.
- RT carrega Ki.
- Start abre pausa.


## 16. Enemy intelligence hierarchy

- Training Fighter target bar should identify it as `Uncommon`.
- Fire Ki Blast from long range several times:
  - enemy should occasionally sidestep;
  - if it does not dodge, it may turn toward the projectile and block;
  - missed projectiles should not trigger defensive reactions.
- Fire Ki Blast at close range:
  - dodge should be less likely;
  - guard should be the primary defensive response.
- Use punch/kick near the enemy:
  - it should occasionally face the Player and guard;
  - blocked hits should not cause normal hurt knockback.
- After some successful blocks, the Uncommon fighter may counterattack.
- Confirm the enemy occasionally approaches at an angle instead of always walking in a perfectly straight line.
- Temporarily change `EnemyAIComponent.profile` to:
  - `common.tres`: noticeably slower and less defensive;
  - `elite.tres`: frequent blocks/dodges and more tactical movement;
  - `boss.tres`: fastest reactions and highest defensive consistency.
- Confirm none of the tiers reacts with 100% certainty.
