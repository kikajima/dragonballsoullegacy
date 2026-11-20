# Estudo de evolução do DBSL — HU2 e trilogia LoG

Data: **01/11/2026**. Recomendação: transformar os sistemas existentes em uma experiência completa de exploração, combate, recompensa e compra de técnicas antes de ampliar o catálogo. A identidade proposta é combate de leitura clara, mapas com a apresentação GBA e progressão/social próprios do MMORPG.

Este é um estudo abrangente dos sistemas e materiais disponíveis, **não uma engenharia reversa integral das ROMs nem uma campanha dos quatro jogos concluída em teste**. Não foram medidos tempos por frame, fórmulas internas ou todos os encontros dos originais. As propostas abaixo são decisões para DBSL; não pressupõem fidelidade literal.

## Evidências e cobertura

| Fonte | Conferido nesta revisão | Limite |
| --- | --- | --- |
| HU2 master | 78 arquivos de código, 11.430 linhas; hashes Git de todos os arquivos idênticos ao [diretório remoto](https://github.com/DarkerLegends/HeroesUnited2/tree/master/Code); manifesto de compilação e fluxos principais | Análise estática; servidor BYOND não executado |
| HU2 Dev | 73 arquivos; comparação com master, diferenças de regras e recursos incluídos | Não confundir esta versão com master |
| LoG I / LoG II / Buu's Fury | Três ROMs locais identificadas; tentativas reais no REA; manuais; inventário e integridade das imagens | Capturas de emulador de sessões anteriores não são novas medições de combate |
| Biblioteca GBA | 49 / 102 / 119 PNGs, respectivamente; **270 imagens legíveis**, verificadas com Pillow; revisão visual das duas folhas da ilha de Roshi | Integridade da imagem não confirma todas as poses, colisões ou animações |
| DBSL atual | Código, recursos das técnicas e execução de testes no Godot; 17 técnicas em quatro direções; cinco mapas | O protótipo local ainda não equivale a um servidor MMORPG |

Detalhes de HU2: [HU2_CODE_STUDY.md](HU2_CODE_STUDY.md), com evidências por arquivo/linha e cobertura dos 78 arquivos. Detalhes das ROMs/saves: [GBA_REFERENCE_ANALYSIS.md](GBA_REFERENCE_ANALYSIS.md). Recortes já integrados: [MAP_ASSETS.md](MAP_ASSETS.md).

### O que o REA realmente fez

Executados `rea --version`, `rea doctor`, `rea capabilities`, importação da pasta `Code` e `rea analyze` para **cada uma das três ROMs**. Versão local: **6.5.0**.

- ROMs: `capability_unavailable / unsupported_provider`; o adaptador Ghidra para Windows rejeita `raw-binary` ARM. Também falta configurar Ghidra. Instalar somente o motor não remove a restrição do adaptador.
- Código HU2: `import-reference-source` retorna `unsupported_host`, porque a abertura segura sem seguir links não está disponível nesse host. O comando indica Linux/WSL ou macOS. WSL não está instalado.
- Assim, **nenhuma fórmula ou mecânica foi descoberta por descompilação REA**. O estudo continuou pela leitura do código disponível, fontes documentais e recursos locais. Não foi usado o executável do emulador como substituto do código dos jogos.

Saídas brutas locais: `references/roms/analysis/rea-*-2026-11-01.json`. Comparação GitHub e inventário: `hu2-github-code-index.json` e `reference-study-inventory.json`, na mesma pasta ignorada pelo Git.

```powershell
rea import-reference-source ../HeroesUnited2-master/Code --detail summary --format json
$romPath = (Get-ChildItem references/roms -Filter '*Goku II*.gba').FullName
rea analyze $romPath --target-format raw-binary --architecture arm --entry-point 0x08000000 --provider ghidra --format json
```

O endereço acima é uma hipótese de mapeamento para a tentativa, não um ponto de entrada de código validado. Uma investigação futura em ambiente compatível ainda precisa distinguir ARM/Thumb, localizar dados comprimidos e relacionar funções a observações no emulador.

## O que aproveitar de cada referência

| Referência | Sistemas documentados | Interpretação para DBSL |
| --- | --- | --- |
| LoG I | Combate próximo/Ki, carga, recuperação por itens, missões e voo com reserva limitada; acabar a reserva sobre terreno inválido devolve ao ponto de partida. [Manual](https://manuals.plus/m/f6e883e70127290b40f6b2c0d773a66ff4f7fcf7423b19a0f5fd060e73904fb0) | Começo compreensível; poucos comandos ensinados por situações. Se houver voo, definir pouso e retorno seguros antes de abrir água e penhascos. |
| LoG II | Corrida, obstáculos destrutíveis, mapa explorado, scouter, diário, treino de golpe carregado, atributos e transformações. Há barreiras por personagem/nível. [Manual](https://manuals.plus/m/da998affe7261d9d71327112494d7a42054847f2e19503b9c2f3d23167744c79) | Exploração com informação útil. Substituir exclusividade de personagem por requisitos universais de missão, aprendizado ou domínio. |
| Buu's Fury | Defesa, equipamentos em quatro categorias, atributos, melhorias de técnicas, objetivos classificados, viagem, fusão e dois modos de duelo por cabo: balanceado e baseado no save. [Manual](https://manuals.plus/m/82cf096086dcce476c73d2fdb5692b88441886ec403666d4448c46afae4e74d0) | Escolhas de construção do personagem e economia. Separar arena competitiva equalizada de progressão PvE; o multiplayer por cabo não demonstra coop de campanha nem arquitetura MMO. |
| HU2 | Treino ativo, grupos, missões instanciadas, eventos, clãs e disputas de feixes; ativação varia entre master e Dev. [Estudo de código](HU2_CODE_STUDY.md) | Fonte de atividades recorrentes e integração social. Adaptar objetivos e regras ao Godot, preservando controle contínuo e técnicas universais. |

No HU2, tutorial e implementação divergem: master concede três pontos por nível, mas a descrição e o respec ainda pressupõem um; partes de desgaste da guarda estão comentadas. Crafting completo não foi confirmado. Portanto, copiar números ou nomes de sistemas sem verificar o fluxo produziria erros novos.

## Diagnóstico do projeto atual

| Área | Base existente | Lacuna concreta |
| --- | --- | --- |
| Combate | Melee, Ki, feixes, explosões, guarda direcional/perfeita, dash, status, combo e transformações | Balancear recuperação, interrupção e controle de grupo; ensinar diferenças entre técnicas |
| Técnicas | `SpecialAttackData`, 17 recursos, desbloqueios e oito slots persistentes | `unlock_all_for_prototype = true`; aquisição comercial e uma interface de montar conjunto ainda não fecham o fluxo jogável |
| Economia | Carteira, loot físico, inventário, `ShopComponent.buy/sell` | Loja não está conectada a NPC/cena; compra de item não é compra de técnica |
| Progressão | XP e aumento automático de HP, Ki e dano por nível | Sem construção explícita por atributos/equipamento; evitar somar bônus duas vezes ao carregar ou transformar |
| Mundo | Ilha, casa, cidade, ermo e sala de treino; portais/checkpoints; recortes integrados | Poucos objetivos espaciais, segredos e decisões de rota; decoração precisa ter função |
| Inimigos | Perfis de reação/defesa, retorno ao spawn, loot e suporte a encontros | Ilha/cidade/ermo reutilizam `debug_goku_enemy.tscn`; faltam identidades e padrões próprios |
| Missões | Roshi, rastreador, recompensas e treino | Falta uma sequência de aventura com início, exploração, clímax e retorno |
| Interface | HUD autoral compacta, técnica abaixo de vida/Ki, notificações e diálogo | Sem mapa/scouter/inventário visual completo; manter informações secundárias em telas abertas pelo jogador |
| Áudio | Não identifiquei uso de `AudioStreamPlayer` nas cenas/scripts de gameplay pesquisados | Impactos, carga, confirmação, passos e ambiente precisam de canais e volume configurável |
| Online | Componentes locais e save JSON | Não identifiquei RPC/peer de rede no gameplay; autoridade, persistência, instâncias e reconexão precisam de uma camada própria |

Arquivos de partida: `combat/special/special_attack_component.gd`, `components/abilities/ability_loadout_component.gd`, `components/economy/shop_component.gd`, `components/progression/level_stats_component.gd`, `components/ai/enemy_ai_component.gd`, `systems/training/training_manager.gd` e `core/save/save_manager.gd`.

## Plano recomendado

P0 = fechar a experiência atual; P1 = ampliar progressão/exploração; P2 = expandir atividades; P3 = conteúdo social avançado. São prioridades propostas, sem prazo artificial.

| Prioridade | Entrega | Como fazer no DBSL | Critério de conclusão |
| --- | --- | --- | --- |
| P0 | Aquisição universal de técnicas | Catálogo com preço/requisito/descrição; treinador; débito e desbloqueio como uma transação; modo de testes separado do modo normal | Qualquer personagem compra, equipa, usa e recarrega save; compra repetida não cobra; falha não perde Zeni |
| P0 | Conjunto equipado utilizável | Ligar os oito slots existentes à seleção; tela de gestão fora da HUD; manter R/O e indicação compacta | Slots vazios/duplicados tratados; técnica não equipada não aparece inesperadamente; troca não ignora cooldown |
| P0 | Uma aventura completa | Roshi ensina → tarefa na costa → viagem à cidade → confronto no ermo → retorno e recompensa útil | Jogador entende o próximo objetivo; morte/viagem/load não quebram a missão; recompensa concedida uma vez |
| P0 | Três papéis de inimigo | Lutador próximo, atirador e elite; sprites existentes; preparação visível, janela de esquiva e recuperação | Cada adversário exige decisão diferente; não lê input instantaneamente nem mantém stun infinito |
| P0 | Áudio de ação | Serviço de som com buses, limite de vozes e eventos de acerto/carga/erro | Feixe não empilha dezenas de sons; volume persiste; som confirma somente acertos reais |
| P1 | Destrutíveis e segredos | Rocha/caixa/baú com vida, estado persistente e loot; abrir um atalho ou revelar item | Não duplica loot ao carregar/reentrar; arte quebrada e colisão desaparecem juntas |
| P1 | Diário e mapa descoberto | Objetivo ativo, marcadores de saída/treinador/checkpoint e áreas visitadas; scouter como registro de inimigos | Abre sem cobrir permanentemente o jogo; progresso de exploração persiste |
| P1 | Equipamentos e consumíveis | Pequeno catálogo; comparação de atributos; slots definidos em dados; comida/Ki com regras de uso | Equipar/desequipar/load/transformar não acumulam bônus; nenhum item sem finalidade |
| P1 | Domínio das técnicas | Evolução por desafios/acertos úteis; melhorias escolhidas em vez de simples inflação de dano | Dano em alvo invulnerável não dá progresso; treino artificial não supera toda a aventura |
| P1 | Viagem e voo delimitados | Começar por destinos descobertos e travessias sinalizadas; validar posição de pouso | Sem sair do mapa, ignorar missão ou ficar preso quando acaba Ki |
| P2 | Chefes, instâncias e objetivos opcionais | Chefe com padrões por fase, desafios de treino e bônus de exploração; usar `EncounterSpawner` | Entrada/saída/repetição seguras; recompensas e reset definidos |
| P2 | Companheiro e duelo | Companheiro simples primeiro; arena com convite e regras explícitas | Companheiro não bloqueia portas; desistência e derrota encerram arena corretamente |
| P3 | Clãs, fusão compartilhada e disputa de feixes | Conteúdo posterior ao protótipo de rede; permissões e ownership explícitos | Desconexão não duplica personagem/itens; participante não fica preso em ação compartilhada |

### Rede: começar o desenho cedo, limitar a primeira entrega

O objetivo MMORPG já está definido. Mesmo com conteúdo social avançado em P3, o desenho de autoridade deve começar junto de P0: compra, desbloqueio, dano, XP e loot precisam de comandos validados e IDs estáveis. A primeira prova online deve conter **dois jogadores, um inimigo, uma compra e uma recompensa**, com servidor decidindo resultados. Testar latência, comando repetido e reconexão antes de multiplicar mapas.

Os saves locais permanecem úteis para desenvolvimento. No online, carregar save não pode restaurar recursos/recargas, e abrir diálogo/inventário não pode pausar o mundo inteiro. `get_tree().paused` em `DialogueBox` e `PauseMenu` precisa virar bloqueio local de entrada na modalidade online. A economia persistente exige débito/crédito indivisíveis e operações repetidas sem recompensa duplicada.

## Atualizar as habilidades sem perder suas diferenças

O manual de LoG II distingue feixe sustentado, feixe perfurante, granada em arco, dispersão, explosão carregada, stun e golpes próximos. Descreve Spirit Bomb crescente, lenta e explosiva; não fornece aqui medições de duração/dano. [Manual de LoG II — ataques](https://manuals.plus/m/da998affe7261d9d71327112494d7a42054847f2e19503b9c2f3d23167744c79).

| Técnica | Base já presente no DBSL | Atualização proposta |
| --- | --- | --- |
| Kamehameha | Canalização, drenagem e continuidade após derrotar o alvo | Manter a regra do usuário; medir dano/Ki por segundo, término em parede e reação ao interromper |
| Special Beam Cannon | `beam_pierces_targets = true`, termina no cenário | Distinguir claramente a largura/impacto; testar dois alvos e parede atrás deles |
| Spirit Bomb | Pose de mãos erguidas, crescimento, projétil lento e área | Mostrar risco/alcance e sinal de carga; para MMO substituir stun dependente da tela por área/range explícito |
| Masenko | Arco e explosão no destino | Sombra de aterrissagem e indicação de alcance; trajetória deve comunicar onde o dano ocorre |
| Burning Attack | Projétil com atordoamento | Resistência temporária a stun repetido e regra específica para chefes/PvP |
| Scatter Shot / Big Bang | Dispersão / explosão carregada | Ajustar cobertura contra concentração de dano; cada escolha precisa ter situação favorável |
| Golpes físicos especiais | Ataques próximos e sequências | Antecipação, reação e recuperação próprias; impedir deslocamento visual que descole a hitbox |
| Transformações | Super Saiyan e Super Namek | Mostrar manutenção e encerramento; escolher diferenças de função sem bloquear técnicas pela aparência |

Valores atuais dos `.tres` são parâmetros do DBSL, não números extraídos das ROMs. O teste de 68 casts confirma execução e estados, não balanceamento nem equivalência aos originais.

## Direção gráfica e construção dos mapas

Nas folhas locais de Roshi de LoG II e Buu's Fury, a casa é um marco central, há faixa de areia separando grama e água, objetos se agrupam perto de usos reconhecíveis e a silhueta da costa permanece legível. Buu's Fury inclui píer e círculos; LoG II inclui ilhotas vizinhas. Essa comparação foi visual, nas folhas `Master Roshi Island__584997.png` e `Roshi's Island__54382.png`.

Aplicação proposta:

1. Organizar ilha em chegada, treino, descanso e saída. Preservar passagem entre Roshi, casa e checkpoint; não aumentar a densidade de decoração indiscriminadamente.
2. Reduzir contraste visual da água ao fundo para destacar personagem/ataques. Manter paleta coerente entre HU2 e GBA, sem desfocar pixels.
3. Padronizar escala, pivô nos pés, sombra e profundidade; colisão deve representar a base sólida, não toda a copa/telhado.
4. Transformar West City em centro funcional: treinador, loja, viagem e NPC de missão. Usar os prédios/móveis já catalogados e sinalizar portas utilizáveis.
5. Dar ao ermo coberturas, rotas alternativas, aviso de combate e espaço seguro para entender o chefe. Cada obstáculo novo precisa de teste de feixe, projétil e caminho da IA.
6. Manter a HUD autoral em 50% e a técnica abaixo de vida/Ki. Inventário, mapa, catálogo e descrição extensa ficam em telas próprias.

Não é necessário obter novos sprites para a próxima entrega: a biblioteca conferida já contém ambientes, objetos e dezenas de folhas de inimigos. Um mapa extraído é referência visual; não fornece automaticamente tiles reutilizáveis, colisão, pontos de interação e navegação.

## Validação e pendências do estudo

As correções iniciadas antes deste estudo foram verificadas: carregar limpa combate/dash/treino antigos; salvar durante derrota não sobrescreve o save saudável; portais recuperam falha e coordenam morte/viagem; diálogos longos são paginados e restauram a pausa. Testes: `test_save_runtime`, `test_world_transitions`, `test_dialogue_pages`, `test_player_recovery`, `audit_gameplay` e `test_special_catalog`. O último realizou **68 casts, zero falhas**. Instruções em [TESTAR_AREIA_E_SKILLS.md](TESTAR_AREIA_E_SKILLS.md).

Para fechar a investigação comportamental dos originais ainda faltam: medidas por frame em saves adequados, colisões de cada técnica, interrupções, dois alvos alinhados, inimigos/chefes representativos e progressão sem saves alterados. Registrar ROM/hash, versão do emulador, estado inicial, entrada e resultado; não converter descrições de manual em medições.

**Primeira entrega recomendada:** treinador com compra universal + conjunto equipado + uma missão completa + três inimigos distintos. Ela dá finalidade às técnicas, aos mapas, ao Zeni e ao treino que já existem.
