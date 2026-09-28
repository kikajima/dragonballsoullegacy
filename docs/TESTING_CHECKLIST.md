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


## 17. Tier difficulty scaling

- Training Fighter currently uses `Uncommon` and should start slightly tougher than its old base values.
- Switching to `Common` should restore approximately base HP/damage/speed/rewards.
- Switching to `Elite` should noticeably increase HP, damage, movement, XP and loot.
- Switching to `Boss` should create a major HP increase and the highest reward multiplier.
- Kill/respawn the same debug enemy multiple times and confirm the multipliers are **not** applied repeatedly.
- Fire a projectile with a wall between the projectile and enemy; the AI should not dodge/block a shot that will be stopped by world geometry first.


## 18. Projectile clash collisions

- Fire a Player Ki Blast directly against an enemy Ki Blast.
- The two projectiles must stop at the collision point.
- Both should enter their impact visual instead of crossing through each other.
- Neither projectile should damage Player or enemy after the clash.
- Repeat at close range and long range.
- Repeat with diagonal enemy shots.
- Fire two shots that pass beside each other; they must not clash when their collision radii do not overlap.
- Confirm a wall closer than the opposing projectile still absorbs the shot first.
- Confirm consecutive Ki Blasts travelling in the same direction do not destroy each other unless their actual collision shapes overlap.


## 19. Special energy attacks

- Confirm the local files exist:
  - `assets/sprites/effects/legacy/special_attack_sfx.png`;
  - `assets/sprites/characters/goku/processed/goku_buus_fury_beam_cast.png`.
- Press R repeatedly and confirm the selector cycles through all eight techniques.
- Press O and confirm the selected technique consumes Ki and enters cooldown.
- Projectile techniques must use the Ki Blast-style character pose.
- Kamehameha and Special Beam Cannon must use the two-handed beam pose.
- Confirm Player movement is locked during each special cast.
- Test Kamehameha and Special Beam Cannon horizontally and vertically.
- Beams must stop at solid world/NPC geometry.
- Test Spirit Bomb, Masenko Ha, Big Bang Attack, Burning Attack and Sword Blast against the Training Fighter.
- Burning Attack should temporarily stop the Training Fighter.
- Scatter Shot must create three diverging projectiles without the three shots destroying each other.
- Fire a special projectile against an enemy Ki Blast; both should clash and stop.
- Fire two projectiles from the same Player in the same direction; they should not clash with each other.
- Verify cooldown text in the SpecialAttackHUD.


## 19. Legacy of Goku II special attack behaviors

- Cycle with R and confirm all prototype techniques are selectable.
- Kamehameha:
  - hold O;
  - beam remains active;
  - Ki drains continuously;
  - release O and confirm beam ends.
- Special Beam Cannon:
  - hold O;
  - verify multiple aligned enemies can be hit;
  - verify scenery stops the beam.
- Masenko Ha:
  - tap O for short/weak arc;
  - hold then release for longer/stronger arc;
  - confirm damage occurs at landing/explosion.
- Scatter Shot:
  - hold/release;
  - exactly three projectiles should fan outward;
  - longer charge should increase travel range.
- Big Bang Attack:
  - sphere should grow while charging;
  - release should create a larger explosive projectile at high charge.
- Spirit Bomb:
  - sphere should grow above Goku while charging;
  - projectile should be slow;
  - impact should create a large area hit and stun nearby enemies.
- Burning Attack:
  - direct hit should stun the Training Fighter.
- Sword Blast:
  - confirm melee contact and energy wave are both emitted.
- Energy Punch:
  - confirm short forward movement and powered melee hit.
- Super Kick / Two-Handed Smash / Cross Slash:
  - hold and release;
  - confirm forward lunge;
  - high charge should deal more damage.
- Spin Punch:
  - place enemies around the player and confirm radial hit behavior.
- Flurry Punch:
  - confirm rapid multi-hit sequence rather than one large hit.
- Peace Sign Pose:
  - nearby enemy should be stunned without a projectile.
- Confirm special projectiles still participate in projectile-vs-projectile clashes.
- Confirm older saves do not permanently hide prototype specials.
