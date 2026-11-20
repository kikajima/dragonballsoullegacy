# Estudo estático de Heroes United 2

Data: 2026-11-01. Fontes locais: `../HeroesUnited2-master` e `../HeroesUnited2Dev-master`. Este documento descreve código, não uma sessão jogada nem uma compilação validada. Os números de linha abaixo são da árvore **master**, salvo indicação **Dev**. Não foram transplantados código, diálogos ou assets para DBSL.

## Escopo e limites

Inventário integral de `Code`: master tem **78 arquivos / 11.430 linhas**; Dev tem **73 / 11.098**. Comparação normalizada de finais de linha encontra **44 arquivos iguais**, **29 pares com diferenças** e **5 arquivos exclusivos de master**. Todos foram inventariados e classificados; a leitura detalhada concentrou-se nas implementações e chamadas de combate, treino, progressão, missões, itens e sistemas sociais. Arquivos auxiliares e históricos foram examinados por declarações, referências e diferenças, sem alegação de revisão linha a linha de todas as 22.528 linhas.

O manifesto `HeroesUnited2.dme` inclui 71 arquivos de master e todos os 73 de Dev. Em master, **CapsuleChars, EventClanWars, TerritoryWars, MineCraft e GlobalMutes não entram no build declarado**, assim como `Ban.dm` e `closed testing.dm`. Inicializações de cápsulas, territórios e mineração estão comentadas em `Main.dm:33`, `Main.dm:53`. `MissionMaker.dm` está vazio. A existência de arquivo, nome de sprite, tutorial ou entrada no changelog não demonstra recurso funcionando.

## Mecânicas verificadas e aplicação em DBSL

| Sistema | Evidência estática | Aplicação recomendada |
| --- | --- | --- |
| Corpo a corpo | `SkillVerbs.dm:89`: combo padrão de cinco golpes, último arremessa, acertos devolvem 5% de Ki; `SkillVerbs.dm:153`: ataque forte carregado; `SkillProcs.dm:35`: bloqueios explícitos de ação por stun, guarda, carga, KO etc. | **P0**: consolidar estados, antecipação, acerto, reação e recuperação. Um combo curto deve comunicar o último golpe e abrir distância. Ajustar tempos ao movimento contínuo de DBSL, sem portar tiles/ticks. |
| Defesa e contra-ataque | `Procs.dm:256`: esquiva por toque de guarda consome 20% de Ki, ou 10% com perk, teleporta e contra-ataca; `Blasts.dm:81`: ataque/contra-ataque pode devolver projétil. | **P1**: guarda legível, contra-ataque com janela ensinada e custo claro. Evitar resposta aleatória invisível ao jogador. |
| Divergência da guarda | Em master, desgaste está comentado em `NpcEnemies.dm:4`, recarga em `Procs.dm:43`, requisito de guarda em `SkillVerbs.dm:240`. Em **Dev `NpcEnemies.dm:3`**, desgaste, quebra e recuperação são implementados; `Movement.dm:33` de Dev reduz velocidade com guarda baixa. | Não afirmar que master possui guarda quebrável funcional com base no tutorial. Escolher uma regra única para DBSL; validar ataque forte e quebra contra jogador e IA. |
| Ki e feixes | `SkillVerbs.dm:269`: blast normal custa 10% Ki, perseguidor 20%, cura usa vida; `SkillVerbs.dm:291`: feixe começa com 20% Ki, pode acumular até 20 incrementos adicionais. `Beams.dm:11`: até cinco pulsos; `Beams.dm:84`: termina no primeiro adversário/obstáculo e limpa depois de 15 ticks fora de disputa. | **P0**: preservar a decisão de DBSL: feixe sustentado e continuidade após morte. Absorver clareza de carga/custo/impacto; não copiar a duração fixa nem o encerramento no primeiro alvo. |
| Disputa de feixes | `Beams.dm:45` e `ButtonCombos.dm:13`: sequências de cinco direções movem o ponto de encontro; vencedor causa dano ampliado. | **P2**: confronto raro e bem sinalizado depois do combate básico; oferecer alternativa acessível ao QTE. |
| Movimento/voo | `Movement.dm:9`, `Movement.dm:77`: duplo toque ativa corrida, oito direções por `step`; `SkillVerbs.dm:328`: voo muda densidade/camada e proíbe certas ações. | Preservar deslocamento contínuo. Usar voo para leitura de altura, travessia e efeitos, com colisão separada da animação; não converter DBSL para grade. |
| IA | `NpcAI.dm:14`: aquisição e abandono de alvo, recarga de Ki, perseguição, tentativa de forte contra guarda e feixe contra carga alinhada; `NpcAI.dm:52`: sem alvo, recupera recursos e volta ao ponto inicial. | **P0**: primeiro inimigos com papéis claros e ataques antecipados; depois defesa e reação contextual. Não confundir probabilidades e seleção de personagem com variedade real de comportamento. |
| Dano e KO | `SkillProcs.dm:253`: duelos/eventos balanceados e qualquer combate envolvendo NPC usam dano proporcional à vida; base de 20 acertos, dobrada contra NPC antes de modificadores. `SkillProcs.dm:113`: corpo a corpo pode nocautear; energia finaliza; `Procs.dm:133`: missão admite fantasma/retorno. | Balancear PvE pelo tempo para vencer e janelas de defesa. Não prometer que aumentar atributos produz efeito linear: o caminho balanceado substitui o dano inicial. Separar KO, morte e reaparecimento explicitamente. |
| Treino | `Training.dm:69`: sequência direcional; `Training.dm:223`: saco com janela temporal; `Training.dm:159`: gravidade preserva sequência, mas erro retira 10% de vida; `Training.dm:179`: parceiro fraco/equilibrado/forte; `Training.dm:198`: foco concede EXP passivo. | **P1**: dojo com três provas curtas: acerto/defesa/controle de Ki. Mestres podem conceder técnicas por domínio demonstrado. Dar preferência a treino ativo e recompensa definida; não exigir sessões longas de repetição. |
| Progressão numérica | `Training.dm:41`: 100 EXP por nível, teto 999.999; master dá três pontos/nível, **Dev `Training.dm:49`** dá um. `Stats.dm:75`: vida +10, Ki +20, força +2, defesa +1 por ponto. Perk a cada 10.000 níveis (`Training.dm:58`). | **P1**: escalas pequenas e compreensíveis, poucos marcos relevantes; não importar números inflacionados. Risco concreto: master `Procs.dm:210` devolve só nível total menos um no respec e `Tutorials.dm:69` anuncia um ponto, divergindo dos três concedidos. |
| Técnicas e personagens | `Characters.dm:1`: troca livre de personagem quando pode agir; `Characters.dm:45`: especial e transformações ficam no personagem; `CharSpecials.dm:1`: transformação pode substituir o feixe. Perks têm três slots, dois inicialmente fechados (`Perks.dm:12`). | **P1**: separar identidade visual de biblioteca de técnicas. A regra do usuário continua: **qualquer personagem pode aprender todas as habilidades**. Mestres/provas/maestria são proposta para DBSL; não foi encontrado currículo de técnicas universais em HU2. |
| Missões | `Missions.dm:15`: seis definições com chefe e grupos de adversários; `NPCs.dm:26`: NPC oferece seleção; `ConceptPieces.dm:57`: montagem por peças conectadas, até nove etapas, inimigos e 1–3 baús; `Missions.dm:66`: derrotar todos e saquear todos dá bônus dividido pela party. | **P0/P1**: ciclo completo falar → objetivo → explorar → lutar → chefe → recompensa → retorno. Aproveitar bônus opcionais, mas garantir uma rota desenhada e interessante antes da geração procedural. HU2 não demonstra campanha extensa com ramificações narrativas. |
| Inventário/economia | `ItemsZenie.dm:1`: moedas físicas com coleta e desaparecimento; `ItemsDestroyable.dm:25`: baú libera moedas e peças; `ItemParts.dm:35`: inventário empilha peças e informa zero esquemas conhecidos; `NPCs.dm:8`: banco. Torneio aceita prêmio financiado pelo jogador (`EventWorldTournament.dm:69`). | **P1**: criar utilidade real antes de multiplicar drops: consumíveis, poucos equipamentos com efeitos claros, compras/recompensas. Não foi identificado loop completo equipar/comprar/vender/fabricar: `TurfType.dm:85` só associa imagens às lojas. |
| Grupo e apoio | `Party.dm:1`: até quatro integrantes, convites e barras; `Blasts.dm:62`: projétil de cura também revive membro fantasma. Cápsulas invocam companheiro e definem desbloqueios em **Dev `CapsuleChars.dm:1`, `CapsuleChars.dm:60`**; chamadas estão desativadas/excluídas em master. | **P2**: companheiro com seguir, ajudar, curar e desobstruir caminho, somente depois do loop solo. Coop requer arquitetura própria e regras de recompensa; presença de código BYOND não fornece rede pronta para Godot. |
| Social/competitivo | `Dueling.dm:36`: desafio aceito com modo balanceado ou por atributos; `EventWorldTournament.dm:69`: individual/party/royale e parâmetros de perks/carga; `Clans.dm:6`, `ClanRanks.dm:17`: cargos/permissões, banco e progressão do clã; `Fusion.dm:100`: dois clientes controlam um mesmo corpo. | **P3**: arenas opcionais, convites ignoráveis e regras visíveis. Adiar clãs, fusão multijogador e temporadas até haver base solo estável e decisão explícita de produto. |
| Exploração/coleção | `DragonBalls.dm:10`, `DragonBalls.dm:59`: sete colecionáveis, pedido diário, respec/progressão/moeda; `EventTreasureHunter.dm:5`: baú dourado periódico; `MiniMap.dm:59`: zonas e marcadores. | **P1/P2**: segredos e objetivos opcionais com mapa claro. Evitar que viagem instantânea irrestrita elimine a exploração planejada. |
| Feedback/onboarding | `GenericProcs.dm:97`: números de dano; `HudEnemy.dm:16`: vida/Ki/rosto do alvo; `Tutorials.dm:85`: tutorial concluído por ação; `Medals.dm:247`: medalha e título. | **P0**: HUD compacto personalizado de DBSL, objetivo atual, Ki/vida, aviso de habilidade indisponível e reação ao dano; **P1**: tutorial contextual dispensável e registro das técnicas. |

## Armadilhas que impedem uma cópia literal

- **Descrições desatualizadas:** tutorial de forte promete quebrar guarda mesmo onde a implementação foi comentada; texto de clan wars promete EXP que `EventFlagWars.dm:18` mantém comentada inclusive em Dev. Texto e changelog são pistas, não prova final.
- **Treino e poder pagos:** assinatura amplia treino (`Training.dm:25`, `Training.dm:213`), dano (`SkillProcs.dm:234`) e pedidos diários (`DragonBalls.dm:63`); criação de clã exige assinatura (`Clans.dm:340`). Não importar essas vantagens como requisitos de design.
- **Peças sem destino:** raridade, nomes de peças e upgrade chamado Crafters United não comprovam crafting. Os testes de raridade em `ItemParts.dm:16` são independentes e podem sobrescrever categoria anterior; não tratar percentuais escritos como distribuição final exclusiva.
- **Código legado acoplado:** estados de combate também usam `icon_state`; chamadas assíncronas compartilham referências mutáveis. Exemplo de revisão necessária: `SkillProcs.dm:58` divide o mesmo acumulador de EXP dentro do laço de clientes fusionados, podendo distribuir quantias diferentes; `SkillVerbs.dm:116` contém expressão suspeita de distância no auto-aim. São observações estáticas, sem reprodução executada.
- **Build não validado:** master inclui duas cópias de Seasonal Cycle que declaram os mesmos nomes; sua ativação principal está comentada. Não foi executado compilador BYOND, nem confirmada compatibilidade com servidor ativo.

## Ordem de aproveitamento

1. **Agora:** estados de combate, clareza de custo/impacto, IA com antecipação, um objetivo e uma missão inteira, HUD atual legível. Medir no jogo: ação responde, dano é previsível, objetivo é entendido, recompensa tem finalidade.
2. **Depois:** treino ativo, mestres e aquisição universal de técnicas, progressão legível, inventário útil, desafios opcionais, tutorial contextual.
3. **Só após consolidar:** companheiros, disputa de feixes, arenas; por último rede, clãs, fusão compartilhada e territórios.

O ganho mais forte de HU2 está na integração entre treino, combate e atividade social. O mapa de sistemas não justifica trazer todos de uma vez. A campanha, os equipamentos e o aprendizado universal desejados por DBSL precisam de desenho próprio, informado também pelas outras referências.

## Apêndice: cobertura por arquivo

Inventário estrutural de todos os arquivos; **igual** compara texto após normalizar finais de linha, sem confundir isso com hash binário. **Fora** significa ausente dos includes do manifesto master. A classificação não declara que cada funcionalidade foi executada.

| Arquivo | Linhas master | Include master | Dev | Área |
| --- | ---: | --- | --- | --- |
| `Apartments.dm` | 46 | incluído | igual | construção de paredes/interiores |
| `Ban and Mute procs.dm` | 9 | incluído | ausente | moderação local |
| `Ban.dm` | 5 | fora | ausente | bloqueio experimental |
| `Beams.dm` | 149 | incluído | igual | feixes e disputas |
| `Blasts.dm` | 127 | incluído | igual | projéteis, cura e efeitos |
| `ButtonCombos.dm` | 50 | incluído | igual | sequências direcionais |
| `CapsuleChars.dm` | 88 | fora | igual | companheiros e desbloqueios |
| `Characters.dm` | 519 | incluído | igual | catálogo/personagens/transformações |
| `CharSpecials.dm` | 105 | incluído | igual | definições de especiais |
| `ClanRanks.dm` | 72 | incluído | igual | cargos/permissões |
| `Clans.dm` | 362 | incluído | difere | clãs e gestão |
| `ClanUpgrades.dm` | 36 | incluído | difere | melhorias de clã |
| `closed testing.dm` | 11 | fora | ausente | acesso de teste |
| `ConceptPieces.dm` | 167 | incluído | igual | geração e ciclo de missões |
| `DragonBalls.dm` | 94 | incluído | igual | colecionáveis e pedidos |
| `Dueling.dm` | 76 | incluído | difere | duelos consentidos |
| `EventClanWars.dm` | 93 | fora | igual | evento de clãs |
| `EventDeathMatch.dm` | 12 | incluído | igual | entrada de interface PvP |
| `EventFlagWars.dm` | 73 | incluído | difere | captura de bandeiras |
| `EventTreasureHunter.dm` | 11 | incluído | igual | baú mundial |
| `EventWorldTournament.dm` | 306 | incluído | igual | torneios |
| `Fusion.dm` | 115 | incluído | difere | fusão compartilhada |
| `GenericProcs.dm` | 319 | incluído | difere | utilitários, feedback e serviços |
| `GetAngle.dm` | 17 | incluído | igual | geometria direcional |
| `GlobalMutes.dm` | 43 | fora | igual | moderação remota |
| `GM.dm` | 180 | incluído | difere | administração |
| `HUD.dm` | 331 | incluído | difere | interface principal |
| `HudEnemy.dm` | 68 | incluído | difere | interface de alvo |
| `HudPopups.dm` | 70 | incluído | igual | convites contextuais |
| `Instances.dm` | 118 | incluído | igual | zonas/arenas/cápsulas |
| `ItemParts.dm` | 116 | incluído | igual | peças e raridade |
| `ItemPickup.dm` | 22 | incluído | igual | coleta por contato |
| `ItemsDestroyable.dm` | 33 | incluído | igual | baús destrutíveis |
| `ItemsZenie.dm` | 44 | incluído | igual | moedas |
| `LowCpuHUD.dm` | 114 | incluído | igual | texto de interface |
| `Main.dm` | 301 | incluído | difere | inicialização/ciclo/login |
| `Medals.dm` | 296 | incluído | difere | conquistas e títulos |
| `MenuVerbs.dm` | 164 | incluído | igual | menus/opções/chat |
| `MineCraft.dm` | 94 | fora | igual | construção/mineração experimental |
| `MiniMap.dm` | 113 | incluído | igual | mapa/marcadores |
| `MissionMaker.dm` | 0 | incluído | igual | vazio |
| `Missions.dm` | 76 | incluído | igual | definições e recompensa |
| `Movement.dm` | 151 | incluído | difere | movimento em grade |
| `Notes.dm` | 44 | incluído | igual | notas de estados/canais |
| `NpcAI.dm` | 65 | incluído | igual | IA de combate |
| `NpcEnemies.dm` | 33 | incluído | difere | defesa e escala NPC |
| `NPCs.dm` | 39 | incluído | igual | banco e missões |
| `OffensiveFilter.dm` | 139 | incluído | difere | chat/antispam |
| `Options.dm` | 36 | incluído | igual | configuração/tutorial |
| `Overlays.dm` | 35 | incluído | igual | sobreposições visuais |
| `Party.dm` | 185 | incluído | difere | grupos/HUD |
| `Perks.dm` | 185 | incluído | difere | vantagens e slots |
| `Procs.dm` | 315 | incluído | difere | utilitários/combatimento/teleporte |
| `ProfileDatums.dm` | 50 | incluído | igual | diagnóstico de objetos |
| `RestrictedFonts.dm` | 20 | incluído | igual | restrição de fontes |
| `Save.dm` | 236 | incluído | difere | persistência/migrações |
| `ScoreBoard.dm` | 60 | incluído | igual | ranking |
| `Seasonal Cycle (Hassan Jalil's conflicted copy 2011-12-12).dm` | 31 | incluído | ausente | cópia sazonal em conflito |
| `Seasonal Cycle.dm` | 34 | incluído | ausente | variação sazonal |
| `SkillProcs.dm` | 334 | incluído | difere | dano/KO/energia/estado |
| `SkillVerbs.dm` | 349 | incluído | difere | ações de combate |
| `StatPanel.dm` | 132 | incluído | difere | painéis de jogador/servidor |
| `Stats.dm` | 94 | incluído | difere | atributos |
| `StatTracking.dm` | 57 | incluído | igual | métricas/recompensas diárias |
| `SubList.dm` | 119 | incluído | difere | assinaturas |
| `SubVerbs.dm` | 110 | incluído | igual | cosméticos de assinante |
| `TerritoryWars.dm` | 100 | fora | igual | controle territorial |
| `TestVerbs.dm` | 323 | incluído | difere | ferramentas de teste |
| `Topics.dm` | 96 | incluído | igual | ações de interface/clã |
| `Training.dm` | 269 | incluído | difere | treino/progressão |
| `Turfs.dm` | 311 | incluído | difere | terreno/portais/teleporte |
| `TurfType.dm` | 157 | incluído | igual | objetos do mundo |
| `Tutorials.dm` | 106 | incluído | igual | tutorial contextual |
| `Updates.dm` | 1875 | incluído | difere | histórico de mudanças |
| `UploadLogger.dm` | 33 | incluído | igual | registro de uploads |
| `Vars.dm` | 86 | incluído | difere | estado/base de atributos |
| `Verbs.dm` | 146 | incluído | difere | social/chat/retorno |
| `VerifyByondVersion.dm` | 30 | incluído | igual | compatibilidade BYOND |
